//
//  ListNameTests.swift
//  MyTaiwanStockTests
//

import XCTest
import CoreData
@testable import MyTaiwanStock

// Same-name lists were creatable from the add-list UI, and renaming a list
// silently did nothing.
//
// These tests swap LocalDBService.shared.container. That is safe only because
// XCTest runs them serially with the other XCTest suites that do the same; do not
// touch LocalDBService.shared from Swift Testing (parallel by default).
final class ListNameTests: XCTestCase {

    private var originalContainer: NSPersistentContainer!
    private var context: NSManagedObjectContext!

    private var onlineDB: MockOnlineDBSyncing!

    override func setUp() {
        super.setUp()
        onlineDB = MockOnlineDBSyncing()
        originalContainer = LocalDBService.shared.container

        // Reuse the singleton's model to avoid ambiguous-entity errors in the test host.
        let inMemoryContainer = NSPersistentContainer(
            name: "MyTaiwanStock",
            managedObjectModel: originalContainer.managedObjectModel
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        inMemoryContainer.persistentStoreDescriptions = [description]
        inMemoryContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }

        LocalDBService.shared.container = inMemoryContainer
        context = inMemoryContainer.viewContext
    }

    override func tearDown() {
        LocalDBService.shared.container = originalContainer
        super.tearDown()
    }

    // MARK: - Add

    func test_saveNewList_whenNameExists_shouldThrowDuplicateAndNotInsert() {
        insertList(name: "自選")
        let sut = makeSUT()

        XCTAssertThrowsError(try sut.saveNewList(listName: " 自選 ")) { error in
            XCTAssertEqual(error as? ListNameError, .duplicate)
        }
        XCTAssertEqual(listNames(), ["自選"])
    }

    func test_saveNewList_whenNameIsBlank_shouldThrowEmptyAndNotInsert() {
        let sut = makeSUT()

        XCTAssertThrowsError(try sut.saveNewList(listName: "   ")) { error in
            XCTAssertEqual(error as? ListNameError, .empty)
        }
        XCTAssertEqual(listNames(), [])
    }

    func test_saveNewList_shouldSaveTrimmedName() throws {
        let sut = makeSUT()

        try sut.saveNewList(listName: " 長期 ")

        XCTAssertEqual(listNames(), ["長期"])
        XCTAssertEqual(sut.listNamesCombine.value, ["長期"])
    }

    func test_localSaveNewList_whenNameExists_shouldNotCreateSecondList() {
        insertList(name: "自選")

        _ = LocalDBService.shared.saveNewListToDB(listName: "自選")

        XCTAssertEqual(listNames(), ["自選"])
    }

    // MARK: - Rename

    func test_updateListName_shouldRenameListInDB() throws {
        insertList(name: "自選")
        let sut = makeSUT()

        try sut.updateListName(at: 0, with: "長期")

        XCTAssertEqual(listNames(), ["長期"])
        XCTAssertEqual(sut.listNamesCombine.value, ["長期"])
    }

    func test_updateListName_whenNameTakenByAnotherList_shouldThrowDuplicate() {
        insertList(name: "A")
        insertList(name: "B")
        let sut = makeSUT()
        let indexOfA = sut.listNamesCombine.value.firstIndex(of: "A")!

        XCTAssertThrowsError(try sut.updateListName(at: indexOfA, with: "B")) { error in
            XCTAssertEqual(error as? ListNameError, .duplicate)
        }
        XCTAssertEqual(listNames(), ["A", "B"])
    }

    func test_updateListName_whenNameIsBlank_shouldThrowEmpty() {
        insertList(name: "自選")
        let sut = makeSUT()

        XCTAssertThrowsError(try sut.updateListName(at: 0, with: " ")) { error in
            XCTAssertEqual(error as? ListNameError, .empty)
        }
        XCTAssertEqual(listNames(), ["自選"])
    }

    func test_updateListName_whenNameUnchanged_shouldSucceed() throws {
        insertList(name: "自選")
        let sut = makeSUT()

        try sut.updateListName(at: 0, with: "自選")

        XCTAssertEqual(listNames(), ["自選"])
    }

    // MARK: - Firestore rename

    // iOS never pulls lists from Firestore, so a list created on Android with the
    // new name is invisible to the local duplicate check. Renaming must merge into
    // it instead of creating a second document with the same name.
    func test_renamePlan_whenNewNameExistsOnline_shouldMergeIntoExistingDocument() {
        let plan = OnlineDBService.makeRenamePlan(
            documents: [
                OnlineListDocument(id: "a", name: "A", stocks: ["2330", "0050"]),
                OnlineListDocument(id: "long", name: "長期", stocks: ["2330", "2454"]),
            ],
            oldName: "A",
            newName: "長期"
        )

        XCTAssertEqual(plan, OnlineListRenamePlan(
            targetID: "long", stocks: ["2330", "2454", "0050"], deleteIDs: ["a"]))
    }

    func test_renamePlan_whenOldNameHasDuplicateDocuments_shouldMergeAllIntoOne() {
        let plan = OnlineDBService.makeRenamePlan(
            documents: [
                OnlineListDocument(id: "a1", name: "A", stocks: ["2330"]),
                OnlineListDocument(id: "b", name: "B", stocks: ["0050"]),
                OnlineListDocument(id: "a2", name: "A", stocks: ["2454", "2330"]),
            ],
            oldName: "A",
            newName: "C"
        )

        XCTAssertEqual(plan, OnlineListRenamePlan(
            targetID: "a1", stocks: ["2330", "2454"], deleteIDs: ["a2"]))
    }

    func test_renamePlan_whenNoConflict_shouldRenameSingleDocument() {
        let plan = OnlineDBService.makeRenamePlan(
            documents: [OnlineListDocument(id: "a", name: "A", stocks: ["2330"])],
            oldName: "A",
            newName: "C"
        )

        XCTAssertEqual(plan, OnlineListRenamePlan(
            targetID: "a", stocks: ["2330"], deleteIDs: []))
    }

    func test_renamePlan_whenOldNameNotOnline_shouldReturnNil() {
        let plan = OnlineDBService.makeRenamePlan(
            documents: [OnlineListDocument(id: "b", name: "B", stocks: [])],
            oldName: "A",
            newName: "C"
        )

        XCTAssertNil(plan)
    }

    // MARK: - Online sync

    func test_saveNewList_shouldUploadThroughInjectedOnlineDB() throws {
        let sut = makeSUT()

        try sut.saveNewList(listName: "長期")

        XCTAssertEqual(onlineDB.uploadedListNames, ["長期"])
    }

    func test_renameList_shouldRenameInOnlineDB() throws {
        insertList(name: "自選")
        let sut = makeSUT()

        try sut.updateListName(at: 0, with: "長期")

        XCTAssertEqual(onlineDB.renamedLists.map(\.newName), ["長期"])
    }

    // The local DB refuses to rename onto a name already in use; Firestore must
    // not be renamed either, or the two sides diverge.
    func test_repositoryRename_whenLocalRejects_shouldNotRenameOnline() {
        insertList(name: "A")
        insertList(name: "B")
        let onlineDB = self.onlineDB!
        let repository = NetworkServiceImpl(onLineDBService: onlineDB)

        repository.updateListName(newName: "B", oldName: "A")

        XCTAssertEqual(listNames(), ["A", "B"])
        XCTAssertTrue(onlineDB.renamedLists.isEmpty)
    }

    // MARK: - Helpers

    private func makeSUT() -> AddListViewModel {
        let onlineDB = self.onlineDB!
        return AddListViewModel(repository: NetworkServiceImpl(onLineDBService: onlineDB))
    }

    private func insertList(name: String) {
        let list = NSEntityDescription.insertNewObject(forEntityName: "List", into: context)
        list.setValue(name, forKey: "name")
        try! context.save()
    }

    private func listNames() -> [String] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "List")
        return try! context.fetch(request)
            .compactMap { $0.value(forKey: "name") as? String }
            .sorted()
    }
}

final class MockOnlineDBSyncing: OnlineDBSyncing {
    private(set) var uploadedListNames: [String] = []
    private(set) var renamedLists: [(oldName: String, newName: String)] = []

    func uploadListToOnlineDB(listName: String) {
        uploadedListNames.append(listName)
    }
    func uploadNewStockNoToOnlineDB(stockNumber: String, listName: String) {}
    func uploadHistoryToOnlineDB(stockNo: String, price: Float, amount: Int, date: Date, status: Int) {}
    func deleteListFromOnlineDB(listName: String) {}
    func renameListInOnlineDB(oldName: String, newName: String) {
        renamedLists.append((oldName, newName))
    }
    func deleteStockNoFromOnlineDB(stockNo: String, listName: String) {}
    func deleteHistoryFromOnlineDB(where historyObject: MyTaiwanStock.InvestHistory) {}
}
