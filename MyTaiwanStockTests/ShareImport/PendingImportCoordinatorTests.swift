//
//  PendingImportCoordinatorTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
final class PendingImportCoordinatorTests: XCTestCase {
    private var container: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var store: PendingImportStore!
    private var coordinator: PendingImportCoordinator!

    private var isAppActive = true
    private var isImportRunning = false
    private var hasModal = false
    private var questions: [(imageCount: Int, answer: (Bool) -> Void)] = []
    private var startedBatches: [PendingImportBatch] = []
    /// Runs while an import is being started, like the stock list appearing and checking again.
    private var whileStarting: () -> Void = {}

    override func setUpWithError() throws {
        container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        store = PendingImportStore(containerURL: container, now: { [unowned self] in clock })
        coordinator = makeCoordinator(store: store)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: container)
    }

    private func makeCoordinator(store: PendingImportStore?) -> PendingImportCoordinator {
        PendingImportCoordinator(
            store: store,
            isAppActive: { [unowned self] in isAppActive },
            isImportRunning: { [unowned self] in isImportRunning },
            hasModal: { [unowned self] in hasModal },
            askToImport: { [unowned self] count, answer in questions.append((count, answer)) },
            startImport: { [unowned self] batch, _ in
                startedBatches.append(batch)
                whileStarting()
            })
    }

    @discardableResult
    private func writeBatch(imageCount: Int) throws -> PendingImportBatch {
        let draft = try store.beginDraft()
        for index in 0..<imageCount {
            let image = container.appendingPathComponent("source\(UUID().uuidString).png")
            try Data([UInt8(index)]).write(to: image)
            try draft.addImage(copying: image, at: index)
        }
        return try draft.commit()
    }

    /// The checks that follow becoming active wait one turn of the run loop, then read the folder off the
    /// main thread.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(50))
        await coordinator.waitForChecks()
    }

    private func becomeActive() async throws {
        coordinator.appDidBecomeActive()
        try await settle()
    }

    private func check() async {
        coordinator.check()
        await coordinator.waitForChecks()
    }

    // MARK: asking

    func test_a_pending_batch_is_asked_about_with_its_image_count() async throws {
        try writeBatch(imageCount: 3)

        try await becomeActive()

        XCTAssertEqual(questions.map(\.imageCount), [3])
        XCTAssertEqual(startedBatches, [], "nothing starts before the user answers")
    }

    func test_no_pending_batch_asks_nothing() async throws {
        try await becomeActive()
        await check()

        XCTAssertEqual(questions.count, 0)
    }

    func test_an_unreachable_container_asks_nothing_and_does_not_crash() async throws {
        coordinator = makeCoordinator(store: nil)

        try await becomeActive()
        await check()

        XCTAssertEqual(questions.count, 0)
    }

    func test_nothing_is_asked_while_an_import_is_running() async throws {
        try writeBatch(imageCount: 1)
        isImportRunning = true

        try await becomeActive()

        XCTAssertEqual(questions.count, 0)
    }

    func test_nothing_is_asked_while_a_modal_screen_is_shown_and_it_is_asked_when_checked_again() async throws {
        try writeBatch(imageCount: 1)
        hasModal = true

        try await becomeActive()
        XCTAssertEqual(questions.count, 0)

        hasModal = false
        await check()
        XCTAssertEqual(questions.count, 1, "the next trigger asks; nothing was queued before")
    }

    func test_nothing_is_asked_while_the_app_is_not_active() async throws {
        try writeBatch(imageCount: 1)
        isAppActive = false

        try await becomeActive()

        XCTAssertEqual(questions.count, 0)
    }

    func test_a_question_still_waiting_for_its_answer_is_not_asked_again() async throws {
        try writeBatch(imageCount: 1)

        try await becomeActive()
        await check()
        coordinator.importDidFinish()
        try await settle()

        XCTAssertEqual(questions.count, 1)
    }

    func test_a_question_that_never_reached_the_screen_is_asked_again_when_the_app_becomes_active() async throws {
        try writeBatch(imageCount: 1)
        try await becomeActive()
        XCTAssertEqual(questions.count, 1, "the question is not shown, and never answered")

        try await becomeActive()

        XCTAssertEqual(questions.count, 2)
    }

    func test_a_question_that_is_still_on_screen_is_not_asked_again_when_the_app_becomes_active() async throws {
        try writeBatch(imageCount: 1)
        try await becomeActive()
        hasModal = true   // the question is on screen

        try await becomeActive()

        XCTAssertEqual(questions.count, 1)
    }

    // MARK: answering

    func test_later_keeps_the_batch_and_is_not_asked_again_until_the_app_becomes_active_again() async throws {
        let batch = try writeBatch(imageCount: 2)
        try await becomeActive()

        questions[0].answer(false)
        await check()
        coordinator.importDidFinish()
        try await settle()

        XCTAssertEqual(questions.count, 1, "at most one question each time the app becomes active")
        XCTAssertEqual(startedBatches, [])
        XCTAssertEqual(store.batches(), [batch])

        try await becomeActive()
        XCTAssertEqual(questions.count, 2)
    }

    func test_now_starts_the_oldest_batch() async throws {
        let oldest = try writeBatch(imageCount: 1)
        clock = clock.addingTimeInterval(60)
        try writeBatch(imageCount: 4)

        try await becomeActive()
        XCTAssertEqual(questions.map(\.imageCount), [1], "the question is about the batch that would start")
        questions[0].answer(true)

        XCTAssertEqual(startedBatches, [oldest])
    }

    func test_the_import_being_started_is_not_offered_again_when_the_list_checks_while_it_starts() async throws {
        try writeBatch(imageCount: 1)
        whileStarting = { [unowned self] in coordinator.check() }
        try await becomeActive()

        questions[0].answer(true)

        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(startedBatches.count, 1)
    }

    func test_the_next_batch_is_asked_about_after_the_import_of_the_first_ended() async throws {
        let first = try writeBatch(imageCount: 1)
        clock = clock.addingTimeInterval(60)
        let second = try writeBatch(imageCount: 2)
        try await becomeActive()
        questions[0].answer(true)
        XCTAssertEqual(startedBatches, [first])

        // The flow deleted the batch once it had a result, then ended.
        store.delete(first)
        coordinator.importDidFinish()
        try await settle()

        XCTAssertEqual(questions.map(\.imageCount), [1, 2])
        questions[1].answer(true)
        XCTAssertEqual(startedBatches, [first, second])
    }

    func test_triggers_that_arrive_together_ask_only_once() async throws {
        try writeBatch(imageCount: 1)

        coordinator.check()
        coordinator.check()
        coordinator.importDidFinish()
        try await settle()

        XCTAssertEqual(questions.count, 1)
    }

    // MARK: the stock list tab

    private func makeStockListTab(topPage: UIViewController? = UIViewController()) throws
        -> (tabs: UITabBarController, navigation: UINavigationController, mock: MockStockListCoordinator)
    {
        let mock = MockStockListCoordinator()
        let viewModel = StockListViewModel(repository: MockNetworkService(), coordinator: mock)
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: AddListViewController.self))
        let list = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "stockListVC") as? StockListViewController)
        list.configure(with: viewModel)
        let navigation = UINavigationController(rootViewController: list)
        if let topPage { navigation.pushViewController(topPage, animated: false) }
        let tabs = UITabBarController()
        tabs.viewControllers = [navigation, UIViewController()]
        tabs.selectedIndex = 1
        return (tabs, navigation, mock)
    }

    func test_showing_the_import_selects_the_list_tab_returns_to_its_root_and_starts_it_there() throws {
        let (tabs, navigation, mock) = try makeStockListTab()
        let source = PendingBatchImageSource(
            batch: PendingImportBatch(folderURL: container, createdAt: clock, imageURLs: []), store: store)

        PendingImportCoordinator.showImport(of: source, in: tabs, navigationController: navigation)

        XCTAssertEqual(tabs.selectedIndex, 0)
        XCTAssertEqual(navigation.viewControllers.count, 1, "the page the user was on is gone")
        XCTAssertEqual(mock.importedSources.count, 1)
        XCTAssertTrue(mock.importedSources.first === source)
    }

    func test_showing_the_import_over_something_that_is_not_the_stock_list_starts_nothing_and_does_not_crash() throws {
        let mock = MockStockListCoordinator()
        let navigation = UINavigationController(rootViewController: UIViewController())
        let tabs = UITabBarController()
        tabs.viewControllers = [navigation]
        let source = PendingBatchImageSource(
            batch: PendingImportBatch(folderURL: container, createdAt: clock, imageURLs: []), store: store)

        PendingImportCoordinator.showImport(of: source, in: tabs, navigationController: navigation)

        XCTAssertEqual(mock.importedSources.count, 0)
    }

    // MARK: expiry

    func test_a_batch_older_than_24_hours_is_deleted_when_checking_and_nothing_is_asked() async throws {
        let old = try writeBatch(imageCount: 1)
        clock = clock.addingTimeInterval(PendingImportStore.maximumBatchAge + 60 * 60)

        try await becomeActive()

        XCTAssertEqual(questions.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.folderURL.path))
    }

    func test_expired_batches_are_left_alone_while_an_import_is_running() async throws {
        let old = try writeBatch(imageCount: 1)
        clock = clock.addingTimeInterval(PendingImportStore.maximumBatchAge + 60 * 60)
        isImportRunning = true

        try await becomeActive()

        XCTAssertTrue(FileManager.default.fileExists(atPath: old.folderURL.path),
                      "the running import may be reading this very batch")
    }

    // MARK: the question and the screens

    func test_the_question_states_the_count_and_its_buttons_answer_now_and_later() throws {
        var answers: [Bool] = []
        let alert = PendingImportCoordinator.makePrompt(imageCount: 3) { answers.append($0) }

        XCTAssertEqual(alert.title, "有 3 張待匯入的截圖")
        XCTAssertEqual(alert.message, "要現在匯入嗎？")
        XCTAssertEqual(alert.actions.map(\.title), ["稍後", "現在匯入"])
        XCTAssertEqual(alert.preferredAction?.title, "現在匯入")

        alert.tapButton(titled: "稍後")
        alert.tapButton(titled: "現在匯入")
        XCTAssertEqual(answers, [false, true])
    }

    func test_a_modal_screen_over_the_window_is_found() throws {
        let root = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        XCTAssertFalse(PendingImportCoordinator.hasModal(in: window))

        root.present(UIViewController(), animated: false)

        XCTAssertTrue(PendingImportCoordinator.hasModal(in: window))
    }
}
