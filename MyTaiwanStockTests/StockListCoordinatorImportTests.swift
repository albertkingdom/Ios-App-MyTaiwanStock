//
//  StockListCoordinatorImportTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
private final class UnreadableSource: TradeImageSource {
    private(set) var loadCount = 0
    var count: Int { 1 }
    func imageData(at index: Int) async throws -> Data {
        loadCount += 1
        throw TradeTextRecognizerError.invalidImage
    }
    func recognitionDidFinish() {}
}

@MainActor
final class StockListCoordinatorImportTests: XCTestCase {
    private var window: UIWindow!
    private var navigation: UINavigationController!
    private var coordinator: StockListCoordinator!
    private var finishedCount = 0

    override func setUp() {
        super.setUp()
        navigation = UINavigationController(rootViewController: UIViewController())
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        coordinator = StockListCoordinator(navigationController: navigation)
        coordinator.onImportFinished = { [unowned self] in finishedCount += 1 }
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        coordinator = nil
        navigation = nil
        super.tearDown()
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 8, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("timed out waiting until \(description)") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func test_the_import_is_in_progress_until_it_ends_and_then_the_coordinator_is_told_once() async throws {
        XCTAssertFalse(coordinator.isImportInProgress)

        coordinator.showImportTrades(of: UnreadableSource(), listNames: [], currentListName: nil, onImported: {})
        XCTAssertTrue(coordinator.isImportInProgress)

        // The unreadable image shows a message, unless the test host is not active and the import is
        // treated as interrupted; either way the import ends.
        try await waitUntil("a message is shown or the import ended") {
            navigation.presentedViewController is UIAlertController || !coordinator.isImportInProgress
        }
        if let alert = navigation.presentedViewController as? UIAlertController {
            XCTAssertTrue(alert.tapButton(titled: "好"))
        }

        XCTAssertFalse(coordinator.isImportInProgress)
        XCTAssertEqual(finishedCount, 1)
    }

    func test_a_second_import_does_not_start_while_one_is_in_progress() async throws {
        let first = UnreadableSource()
        let second = UnreadableSource()
        coordinator.showImportTrades(of: first, listNames: [], currentListName: nil, onImported: {})

        coordinator.showImportTrades(of: second, listNames: [], currentListName: nil, onImported: {})

        try await waitUntil("the first import ended") {
            if let alert = navigation.presentedViewController as? UIAlertController { alert.tapButton(titled: "好") }
            return !coordinator.isImportInProgress
        }
        XCTAssertEqual(first.loadCount, 1)
        XCTAssertEqual(second.loadCount, 0)
        XCTAssertEqual(finishedCount, 1)
    }
}
