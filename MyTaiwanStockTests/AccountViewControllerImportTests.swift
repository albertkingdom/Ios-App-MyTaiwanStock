//
//  AccountViewControllerImportTests.swift
//  MyTaiwanStockTests
//

import XCTest
import CoreData
@testable import MyTaiwanStock

final class MockOnlineDBUploading: OnlineDBUploading {
    private(set) var uploadedListNames: [String] = []
    private(set) var uploadedStockNumbers: [String] = []
    private(set) var uploadedHistoryStockNos: [String] = []

    func uploadListToOnlineDB(listName: String) {
        uploadedListNames.append(listName)
    }
    func uploadNewStockNoToOnlineDB(stockNumber: String, listName: String) {
        uploadedStockNumbers.append(stockNumber)
    }
    func uploadHistoryToOnlineDB(stockNo: String, price: Float, amount: Int, date: Date, status: Int) {
        uploadedHistoryStockNos.append(stockNo)
    }

    var didUploadAnything: Bool {
        !uploadedListNames.isEmpty || !uploadedStockNumbers.isEmpty || !uploadedHistoryStockNos.isEmpty
    }
}

final class AccountViewControllerImportTests: XCTestCase {
    private var window: UIWindow!
    private var originalContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        AccountViewController.resetOfferedImportSessionStateForTesting()
        window = UIWindow(frame: UIScreen.main.bounds)
        originalContainer = LocalDBService.shared.container

        // Swap in an isolated in-memory store (reusing the already-resolved model, see
        // LocalDBServiceCrashFixesTests) so this test controls exactly what "local data"
        // exists, independent of whatever the test host's app-group store contains.
        let inMemoryContainer = NSPersistentContainer(
            name: "MyTaiwanStock",
            managedObjectModel: originalContainer.managedObjectModel
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        inMemoryContainer.persistentStoreDescriptions = [description]

        let loadExpectation = expectation(description: "load in-memory store")
        inMemoryContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5)
        LocalDBService.shared.container = inMemoryContainer
    }

    override func tearDown() {
        LocalDBService.shared.container = originalContainer
        window.rootViewController = nil
        window = nil
        super.tearDown()
    }

    private func seedLocalList(name: String, stockNo: String) {
        let context = LocalDBService.shared.context
        let list = NSEntityDescription.insertNewObject(forEntityName: "List", into: context)
        list.setValue(name, forKey: "name")
        let stockNoObject = NSEntityDescription.insertNewObject(forEntityName: "StockNo", into: context)
        stockNoObject.setValue(stockNo, forKey: "stockNo")
        stockNoObject.setValue(list, forKey: "ofList")
        try? context.save()
    }

    /// AccountViewController's IBOutlets are wired via the storyboard; instantiating it
    /// with a plain init() leaves them nil and crashes on viewDidLoad, so it must be
    /// instantiated the same way the app does (storyboard identifier "accountVC").
    private static func makeAccountViewController() -> AccountViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "accountVC") as! AccountViewController
    }

    // MARK: - Alert presentation wiring (5.1)

    func test_offerLocalDataImportIfNeeded_skipsAlert_whenNoLocalData() {
        let vc = Self.makeAccountViewController()
        window.rootViewController = vc
        window.makeKeyAndVisible()

        let mock = MockOnlineDBUploading()
        vc.offerLocalDataImportIfNeeded(onlineDBService: mock)

        XCTAssertNil(vc.presentedViewController)
        XCTAssertFalse(mock.didUploadAnything)
    }

    func test_offerLocalDataImportIfNeeded_presentsConfirmationAlert_whenLocalDataExists() {
        seedLocalList(name: "我的清單", stockNo: "2330")

        let vc = Self.makeAccountViewController()
        window.rootViewController = vc
        window.makeKeyAndVisible()

        let mock = MockOnlineDBUploading()
        vc.offerLocalDataImportIfNeeded(onlineDBService: mock)

        guard let alert = vc.presentedViewController as? UIAlertController else {
            XCTFail("Expected an import confirmation alert to be presented")
            return
        }
        XCTAssertEqual(alert.actions.map(\.title), ["匯入", "不匯入"])
        // Presenting the choice must not itself upload or mutate anything until the
        // user actually confirms.
        XCTAssertFalse(mock.didUploadAnything)
    }

    // MARK: - Upload fan-out on confirm (5.2)

    func test_importLocalDataToOnlineDB_confirmed_uploadsListsStockNosAndHistory() {
        seedLocalList(name: "我的清單", stockNo: "2330")
        let mock = MockOnlineDBUploading()
        let vc = Self.makeAccountViewController()

        let lists = LocalDBService.shared.fetchAllListFromDB()
        vc.importLocalDataToOnlineDB(lists: lists, onlineDBService: mock)

        XCTAssertEqual(mock.uploadedListNames, ["我的清單"])
        XCTAssertEqual(mock.uploadedStockNumbers, ["2330"])
    }

    func test_declining_import_uploadsNothingAndKeepsLocalDataIntact() {
        seedLocalList(name: "我的清單", stockNo: "2330")

        let vc = Self.makeAccountViewController()
        window.rootViewController = vc
        window.makeKeyAndVisible()

        let mock = MockOnlineDBUploading()
        vc.offerLocalDataImportIfNeeded(onlineDBService: mock)

        guard let alert = vc.presentedViewController as? UIAlertController,
              let declineAction = alert.actions.first(where: { $0.title == "不匯入" })
        else {
            XCTFail("Expected an import confirmation alert with a '不匯入' action")
            return
        }

        // Actually invoke the decline action's handler (rather than merely asserting on
        // state that was already true before any interaction) so this test would fail if
        // a future change wired an upload into the decline branch.
        declineAction.invokeHandlerForTesting()

        XCTAssertFalse(mock.didUploadAnything)
        XCTAssertEqual(LocalDBService.shared.fetchAllListFromDB().count, 1, "declining import must not delete local data")
    }

    // MARK: - Duplicate-prompt prevention within the same session (8.9)

    func test_offerLocalDataImportIfNeeded_doesNotReprompt_onSecondCallInSameSession() {
        seedLocalList(name: "我的清單", stockNo: "2330")

        let firstVC = Self.makeAccountViewController()
        window.rootViewController = firstVC
        window.makeKeyAndVisible()
        let firstMock = MockOnlineDBUploading()
        firstVC.offerLocalDataImportIfNeeded(onlineDBService: firstMock)
        XCTAssertNotNil(firstVC.presentedViewController, "first call in the session should present the alert")

        let secondVC = Self.makeAccountViewController()
        window.rootViewController = secondVC
        window.makeKeyAndVisible()
        let secondMock = MockOnlineDBUploading()
        secondVC.offerLocalDataImportIfNeeded(onlineDBService: secondMock)

        XCTAssertNil(secondVC.presentedViewController, "second call in the same session must not re-prompt")
        XCTAssertFalse(secondMock.didUploadAnything)
    }
}

private extension UIAlertAction {
    /// `UIAlertAction`'s handler closure has no public accessor. Reading it back via KVC on
    /// the private `handler` key is a well-known, test-only technique for exercising an
    /// alert action's actual behavior instead of only asserting on the action's presence.
    func invokeHandlerForTesting() {
        guard let handler = value(forKey: "handler") else { return }
        let handlerBlock = unsafeBitCast(handler as AnyObject, to: (@convention(block) (UIAlertAction) -> Void).self)
        handlerBlock(self)
    }
}
