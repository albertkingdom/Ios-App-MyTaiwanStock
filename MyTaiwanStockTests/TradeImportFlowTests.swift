//
//  TradeImportFlowTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
private final class FakeImageSource: TradeImageSource {
    var results: [Result<Data, Error>]
    var onRecognitionDidFinish: () -> Void = {}
    private(set) var finishedCount = 0

    init(_ results: [Result<Data, Error>] = [.success(Data([1]))]) {
        self.results = results
    }

    var count: Int { results.count }
    func imageData(at index: Int) async throws -> Data { try results[index].get() }
    func recognitionDidFinish() {
        finishedCount += 1
        onRecognitionDidFinish()
    }
}

private final class FakeRecognizer: TradeTextRecognizing, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let result: Result<[RecognizedTextBox], Error>

    init(_ result: Result<[RecognizedTextBox], Error> = .success(TradeScreenshotFixtures.collapsed)) {
        self.result = result
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func recognize(imageData: Data) async throws -> [RecognizedTextBox] {
        lock.lock()
        calls += 1
        lock.unlock()
        return try result.get()
    }
}

@MainActor
final class TradeImportFlowTests: XCTestCase {
    private var window: UIWindow!
    private var navigation: UINavigationController!
    private var flow: TradeImportFlow!
    private var endings: [TradeImportFlow.Ending] = []
    private var importedCount = 0
    private var events: [String] = []
    private var previewRequests: [(trades: [ParsedTrade], listNames: [String], currentListName: String?)] = []

    private let entries = [
        StockListEntry(code: "0050", name: "元大台灣50", market: .tse),
        StockListEntry(code: "2344", name: "華邦電", market: .tse),
    ]

    override func setUp() {
        super.setUp()
        navigation = UINavigationController(rootViewController: UIViewController())
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        flow = nil
        window.isHidden = true
        window = nil
        navigation = nil
        super.tearDown()
    }

    // MARK: helpers

    private func makeFlow(
        recognizer: TradeTextRecognizing = FakeRecognizer(),
        isAppActive: @escaping () -> Bool = { true },
        beforePreview: @escaping () -> Void = {}
    ) -> TradeImportFlow {
        let flow = TradeImportFlow(
            navigationController: navigation,
            listNames: ["我的清單", "另一份"],
            currentListName: "另一份",
            onImported: { [unowned self] in importedCount += 1 },
            onFinished: { [unowned self] in endings.append($0) },
            recognizer: recognizer,
            makeViewModel: { [unowned self] trades, listNames, currentListName in
                events.append("preview")
                beforePreview()
                previewRequests.append((trades, listNames, currentListName))
                return TradeImportViewModel(
                    trades: trades, resolver: StockNameResolver(entries: entries), isKnownCode: { _ in true },
                    store: FakeTradeImportStore(), listNames: listNames, currentListName: currentListName)
            },
            minimumLoadingDuration: .zero,
            isAppActive: isAppActive)
        self.flow = flow
        return flow
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("timed out waiting until \(description)") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private var preview: TradeImportPreviewViewController? {
        navigation.topViewController as? TradeImportPreviewViewController
    }

    private var shownAlert: UIAlertController? {
        navigation.presentedViewController as? UIAlertController
    }

    private func tap(_ title: String, in alert: UIAlertController, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(alert.tapButton(titled: title), "no \(title) button", file: file, line: line)
    }

    private func summary(_ trades: [ParsedTrade]) -> [String] {
        trades.map { "\($0.stockName) \($0.amount.map(String.init) ?? "-")" }
    }

    // MARK: result

    func test_recognized_trades_open_the_preview_with_the_lists_of_the_import() async throws {
        makeFlow().start(importing: FakeImageSource())

        try await waitUntil("the preview is shown") { preview != nil }

        XCTAssertEqual(summary(previewRequests[0].trades), ["元大台灣50 5", "華邦電 3"])
        XCTAssertEqual(previewRequests[0].listNames, ["我的清單", "另一份"])
        XCTAssertEqual(previewRequests[0].currentListName, "另一份")
        XCTAssertEqual(flow.state, .inProgress)
        XCTAssertEqual(endings, [])
    }

    func test_every_image_of_the_source_is_recognized_and_the_trades_are_joined() async throws {
        let recognizer = FakeRecognizer()
        makeFlow(recognizer: recognizer).start(importing: FakeImageSource([.success(Data([1])), .success(Data([2]))]))

        try await waitUntil("the preview is shown") { preview != nil }

        XCTAssertEqual(recognizer.callCount, 2)
        XCTAssertEqual(previewRequests[0].trades.count, 4)
    }

    func test_the_source_is_finished_before_the_preview_is_made() async throws {
        let source = FakeImageSource()
        source.onRecognitionDidFinish = { [unowned self] in events.append("finished") }
        makeFlow().start(importing: source)

        try await waitUntil("the preview is shown") { preview != nil }

        XCTAssertEqual(events, ["finished", "preview"])
        XCTAssertEqual(source.finishedCount, 1)
    }

    func test_no_trade_in_the_images_shows_the_message_after_the_source_finished() async throws {
        let source = FakeImageSource()
        source.onRecognitionDidFinish = { [unowned self] in events.append("finished") }
        makeFlow(recognizer: FakeRecognizer(.success([]))).start(importing: source)

        try await waitUntil("the message is shown") { shownAlert != nil }

        XCTAssertEqual(shownAlert?.title, "找不到可匯入的成交紀錄")
        XCTAssertEqual(events, ["finished"], "no preview is made and the images are already finished with")
        XCTAssertEqual(flow.state, .inProgress)
        tap("好", in: try XCTUnwrap(shownAlert))
        XCTAssertEqual(endings, [.completed])
        XCTAssertEqual(flow.state, .finished)
    }

    func test_an_unreadable_image_shows_the_message_after_the_source_finished_and_writes_nothing() async throws {
        let source = FakeImageSource([.failure(TradeTextRecognizerError.invalidImage)])
        source.onRecognitionDidFinish = { [unowned self] in events.append("finished") }
        makeFlow().start(importing: source)

        try await waitUntil("the message is shown") { shownAlert != nil }

        XCTAssertEqual(shownAlert?.title, "無法讀取圖片")
        XCTAssertEqual(events, ["finished"])
        XCTAssertEqual(previewRequests.count, 0, "no preview, so no trade can be written")
        tap("好", in: try XCTUnwrap(shownAlert))
        XCTAssertEqual(endings, [.completed])
    }

    func test_a_recognizer_error_is_reported_like_an_unreadable_image() async throws {
        struct Failure: Error {}
        let source = FakeImageSource()
        makeFlow(recognizer: FakeRecognizer(.failure(Failure()))).start(importing: source)

        try await waitUntil("the message is shown") { shownAlert != nil }

        XCTAssertEqual(shownAlert?.title, "無法讀取圖片")
        XCTAssertEqual(source.finishedCount, 1)
    }

    // MARK: interruption

    func test_a_cancelled_recognition_keeps_the_images_and_shows_nothing() async throws {
        let source = FakeImageSource([.failure(CancellationError())])
        makeFlow().start(importing: source)

        try await waitUntil("the flow ended") { flow.state == .finished }

        XCTAssertEqual(endings, [.interrupted])
        XCTAssertEqual(source.finishedCount, 0, "an interrupted recognition has no result, so the images stay")
        XCTAssertNil(navigation.presentedViewController, "the loading screen is gone and no message is shown")
        XCTAssertEqual(previewRequests.count, 0)
    }

    func test_an_error_while_the_app_is_not_active_is_an_interruption_not_an_unreadable_image() async throws {
        // Reading a protected file fails once the device is locked.
        let source = FakeImageSource([.failure(CocoaError(.fileReadNoPermission))])
        makeFlow(isAppActive: { false }).start(importing: source)

        try await waitUntil("the flow ended") { flow.state == .finished }

        XCTAssertEqual(endings, [.interrupted])
        XCTAssertEqual(source.finishedCount, 0)
        XCTAssertNil(navigation.presentedViewController)
    }

    // MARK: ending once

    func test_closing_the_preview_ends_the_flow_once() async throws {
        makeFlow().start(importing: FakeImageSource())
        try await waitUntil("the preview is shown") { preview != nil }

        navigation.popViewController(animated: false)

        XCTAssertEqual(endings, [.completed])
        XCTAssertEqual(flow.state, .finished)
        flow.previewDidClose()
        XCTAssertEqual(endings, [.completed], "ending is idempotent")
    }

    func test_importing_and_then_going_back_to_the_list_end_the_flow_once() async throws {
        makeFlow().start(importing: FakeImageSource())
        try await waitUntil("the preview is shown") { preview != nil }

        flow.previewDidImport()

        XCTAssertEqual(importedCount, 1)
        XCTAssertEqual(endings, [.completed])
        // Returning to the list removes the preview, which reports it closed after the animation.
        try await waitUntil("the preview is gone") { navigation.viewControllers.count == 1 }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(endings, [.completed])
        XCTAssertEqual(importedCount, 1)
    }

    func test_the_message_button_ends_the_flow_once() async throws {
        makeFlow(recognizer: FakeRecognizer(.success([]))).start(importing: FakeImageSource())
        try await waitUntil("the message is shown") { shownAlert != nil }

        let alert = try XCTUnwrap(shownAlert)
        tap("好", in: alert)
        tap("好", in: alert)

        XCTAssertEqual(endings, [.completed])
    }

    // MARK: a pending batch

    private func makePendingBatch() throws -> (store: PendingImportStore, batch: PendingImportBatch, cleanUp: () -> Void) {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let store = PendingImportStore(containerURL: container)
        let draft = try store.beginDraft()
        for index in 0..<2 {
            let image = container.appendingPathComponent("shot\(index).png")
            try Data([1, 2, 3]).write(to: image)
            try draft.addImage(copying: image, at: index)
        }
        return (store, try draft.commit(), { try? FileManager.default.removeItem(at: container) })
    }

    func test_a_pending_batch_is_deleted_before_the_preview_is_made() async throws {
        let pending = try makePendingBatch()
        defer { pending.cleanUp() }
        var batchesWhenPreviewWasMade: Int?
        let flow = makeFlow(beforePreview: { batchesWhenPreviewWasMade = pending.store.batches().count })

        flow.start(importing: PendingBatchImageSource(batch: pending.batch, store: pending.store))
        try await waitUntil("the preview is shown") { preview != nil }

        XCTAssertEqual(batchesWhenPreviewWasMade, 0)
        XCTAssertEqual(previewRequests[0].trades.count, 4, "both images of the batch were recognized")
    }

    func test_a_pending_batch_is_deleted_when_its_image_cannot_be_read() async throws {
        let pending = try makePendingBatch()
        defer { pending.cleanUp() }
        try FileManager.default.removeItem(at: pending.batch.imageURLs[1])

        makeFlow().start(importing: PendingBatchImageSource(batch: pending.batch, store: pending.store))
        try await waitUntil("the message is shown") { shownAlert != nil }

        XCTAssertEqual(pending.store.batches(), [])
        XCTAssertEqual(shownAlert?.title, "無法讀取圖片")
    }

    func test_a_pending_batch_stays_when_the_recognition_is_cancelled() async throws {
        let pending = try makePendingBatch()
        defer { pending.cleanUp() }

        makeFlow(recognizer: FakeRecognizer(.failure(CancellationError())))
            .start(importing: PendingBatchImageSource(batch: pending.batch, store: pending.store))
        try await waitUntil("the flow ended") { flow.state == .finished }

        XCTAssertEqual(pending.store.batches(), [pending.batch])
    }

    func test_a_pending_batch_stays_when_its_image_cannot_be_read_while_the_app_is_not_active() async throws {
        let pending = try makePendingBatch()
        defer { pending.cleanUp() }
        try FileManager.default.removeItem(at: pending.batch.imageURLs[1])

        makeFlow(isAppActive: { false })
            .start(importing: PendingBatchImageSource(batch: pending.batch, store: pending.store))
        try await waitUntil("the flow ended") { flow.state == .finished }

        XCTAssertEqual(endings, [.interrupted])
        XCTAssertEqual(pending.store.batches().count, 1)
    }

    func test_the_pending_batch_source_reads_the_images_of_its_batch_and_deletes_it_when_finished() async throws {
        let pending = try makePendingBatch()
        defer { pending.cleanUp() }
        let source = PendingBatchImageSource(batch: pending.batch, store: pending.store)

        XCTAssertEqual(source.count, 2)
        let data = try await source.imageData(at: 0)
        XCTAssertEqual(data, Data([1, 2, 3]))
        XCTAssertEqual(pending.store.batches().count, 1, "reading does not delete")

        source.recognitionDidFinish()

        XCTAssertEqual(pending.store.batches(), [])
    }
}
