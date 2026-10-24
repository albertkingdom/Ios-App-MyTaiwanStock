//
//  DuplicateStockNoTests.swift
//  MyTaiwanStockTests
//

import XCTest
import CoreData
@testable import MyTaiwanStock

// Regression: TestFlight 1.19 (14) crashed on launch because a list in Core Data
// contained the same stockNo twice. These cover every write path that could
// insert duplicates.
//
// These tests swap LocalDBService.shared.container. That is safe only because
// XCTest runs them serially with the other XCTest suites that do the same; do not
// touch LocalDBService.shared from Swift Testing (parallel by default).
final class DuplicateStockNoTests: XCTestCase {

    private var originalContainer: NSPersistentContainer!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
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

    // MARK: - LocalDBService

    func test_localSaveNewStockNumber_whenAlreadyInList_shouldNotInsertDuplicate() {
        let list = insertList(name: "自選")
        let listStruct = MyTaiwanStock.ListStruct(name: "自選", stockNos: [])

        LocalDBService.shared.saveNewStockNumberToDB(stockNumber: "2330", currentFollowingList: listStruct)
        LocalDBService.shared.saveNewStockNumberToDB(stockNumber: "2330", currentFollowingList: listStruct)

        XCTAssertEqual(stockNos(in: list), ["2330"])
    }

    func test_deleteStockNumber_shouldRemoveAllCopiesOnlyFromGivenList() {
        let listA = insertList(name: "A")
        insertStockNo("2330", into: listA)
        insertStockNo("2330", into: listA)
        insertStockNo("0050", into: listA)
        let listB = insertList(name: "B")
        insertStockNo("2330", into: listB)

        LocalDBService.shared.deleteStockNumberInDB(
            stockNoObject: MyTaiwanStock.StockNoStruct(currentPrice: 0, stockNo: "2330"),
            listName: "A"
        )

        XCTAssertEqual(stockNos(in: listA), ["0050"])
        XCTAssertEqual(stockNos(in: listB), ["2330"])
    }

    func test_removeDuplicates_shouldMergeSameNameListsAndDedupeStockNos() {
        let listA1 = insertList(name: "A")
        insertStockNo("2330", into: listA1)
        insertStockNo("2330", into: listA1)
        let listA2 = insertList(name: "A")
        insertStockNo("0050", into: listA2)
        insertStockNo("2330", into: listA2)
        let listB = insertList(name: "B")
        insertStockNo("2330", into: listB)

        LocalDBService.shared.removeDuplicateListsAndStockNos()

        let listsA = fetchLists(named: "A")
        XCTAssertEqual(listsA.count, 1)
        XCTAssertEqual(listsA.first.map(stockNos(in:)), ["0050", "2330"])
        XCTAssertEqual(stockNos(in: listB), ["2330"])
        XCTAssertEqual(countAllStockNos(), 3)
    }

    // An iCloud restore swaps the SQLite file under a running app and then calls
    // reloadPersistentStore(); an old backup may still contain duplicates.
    func test_reloadPersistentStore_shouldRemoveDuplicatesFromRestoredStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reload-\(UUID().uuidString).sqlite")
        let sqliteContainer = NSPersistentContainer(
            name: "MyTaiwanStock",
            managedObjectModel: originalContainer.managedObjectModel
        )
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        sqliteContainer.persistentStoreDescriptions = [description]
        sqliteContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        LocalDBService.shared.container = sqliteContainer
        context = sqliteContainer.viewContext
        defer {
            for store in sqliteContainer.persistentStoreCoordinator.persistentStores {
                try? sqliteContainer.persistentStoreCoordinator.remove(store)
            }
            try? FileManager.default.removeItem(at: storeURL)
        }

        let listA1 = insertList(name: "A")
        insertStockNo("2330", into: listA1)
        insertStockNo("2330", into: listA1)
        let listA2 = insertList(name: "A")
        insertStockNo("0050", into: listA2)

        try LocalDBService.shared.reloadPersistentStore()

        context = sqliteContainer.viewContext
        context.reset()
        let listsA = fetchLists(named: "A")
        XCTAssertEqual(listsA.count, 1)
        XCTAssertEqual(listsA.first.map(stockNos(in:)), ["0050", "2330"])
    }

    // MARK: - Helpers

    @discardableResult
    private func insertList(name: String) -> NSManagedObject {
        let list = NSEntityDescription.insertNewObject(forEntityName: "List", into: context)
        list.setValue(name, forKey: "name")
        try! context.save()
        return list
    }

    private func insertStockNo(_ stockNo: String, into list: NSManagedObject) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "StockNo", into: context)
        object.setValue(stockNo, forKey: "stockNo")
        object.setValue(list, forKey: "ofList")
        try! context.save()
    }

    private func fetchLists(named name: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "List")
        request.predicate = NSPredicate(format: "name == %@", name)
        return try! context.fetch(request)
    }

    private func countAllStockNos() -> Int {
        try! context.count(for: NSFetchRequest<NSManagedObject>(entityName: "StockNo"))
    }

    private func stockNos(in list: NSManagedObject) -> [String] {
        let set = list.value(forKey: "stockNo") as? Set<NSManagedObject> ?? []
        return set.compactMap { $0.value(forKey: "stockNo") as? String }.sorted()
    }
}
