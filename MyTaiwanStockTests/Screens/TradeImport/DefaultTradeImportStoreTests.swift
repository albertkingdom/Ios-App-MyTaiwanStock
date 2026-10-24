//
//  DefaultTradeImportStoreTests.swift
//  MyTaiwanStockTests
//
//  Replaces LocalDBService.shared.container, so like DuplicateStockNoTests it must stay
//  XCTest (serial); do not port it to Swift Testing, which runs in parallel.
//

import XCTest
import CoreData
@testable import MyTaiwanStock

@MainActor
final class DefaultTradeImportStoreTests: XCTestCase {

    private var originalContainer: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var store: DefaultTradeImportStore!

    private let entries = [
        StockListEntry(code: "2344", name: "華邦電", market: .tse),
        StockListEntry(code: "0050", name: "元大台灣50", market: .tse),
    ]

    override func setUp() {
        super.setUp()
        originalContainer = LocalDBService.shared.container
        let container = NSPersistentContainer(name: "MyTaiwanStock", managedObjectModel: originalContainer.managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in XCTAssertNil(error) }
        LocalDBService.shared.container = container
        context = container.viewContext

        store = DefaultTradeImportStore(
            repository: NetworkServiceImpl(onLineDBService: MockOnlineDBSyncing()),
            localDB: LocalDBService.shared)
    }

    override func tearDown() {
        LocalDBService.shared.container = originalContainer
        super.tearDown()
    }

    private func taipei(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TaipeiCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeViewModel(listName: String? = "自選", lists: [String] = ["自選"]) -> TradeImportViewModel {
        let codes = Set(entries.map(\.code))
        let trade = ParsedTrade(
            stockName: "華邦電", date: taipei(2026, 10, 1), price: 179.5, amount: 3, side: .buy,
            tradeTypeText: "盤中零股買進", isSupportedType: true)
        return TradeImportViewModel(
            trades: [trade], resolver: StockNameResolver(entries: entries), isKnownCode: { codes.contains($0) },
            store: store, listNames: lists, currentListName: listName)
    }

    private func insertList(_ name: String) {
        let list = NSEntityDescription.insertNewObject(forEntityName: "List", into: context)
        list.setValue(name, forKey: "name")
        try! context.save()
    }

    private func stockNos(inList name: String) -> [String] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "List")
        request.predicate = NSPredicate(format: "name == %@", name)
        let list = try! context.fetch(request).first
        let set = list?.value(forKey: "stockNo") as? Set<NSManagedObject> ?? []
        return set.compactMap { $0.value(forKey: "stockNo") as? String }.sorted()
    }

    // The test target compiles its own copy of the Core Data classes, so records are read as
    // plain managed objects (as DuplicateStockNoTests does) instead of the app's InvestHistory.
    private func records() -> [NSManagedObject] {
        try! context.fetch(NSFetchRequest<NSManagedObject>(entityName: "InvestHistory"))
    }

    func test_import_stores_the_record_and_adds_the_stock_to_the_list() throws {
        insertList("自選")

        let submitted = try makeViewModel().confirmImport()

        XCTAssertEqual(submitted, 1)
        let record = try XCTUnwrap(records().first)
        XCTAssertEqual(record.value(forKey: "stockNo") as? String, "2344")
        XCTAssertEqual(record.value(forKey: "amount") as? Int, 3)
        XCTAssertEqual(record.value(forKey: "price") as? Float, 179.5)
        XCTAssertEqual(record.value(forKey: "status") as? Int, 0)
        XCTAssertEqual(record.value(forKey: "reason") as? String, "")
        XCTAssertEqual(stockNos(inList: "自選"), ["2344"])
    }

    func test_importing_twice_never_puts_the_same_stock_in_the_list_twice() throws {
        insertList("自選")
        _ = try makeViewModel().confirmImport()

        let second = makeViewModel()
        XCTAssertEqual(second.items[0].status, .duplicate, "the stored record is found through the real store")
        second.toggleSelection(id: second.items[0].id)
        _ = try second.confirmImport()

        XCTAssertEqual(stockNos(inList: "自選"), ["2344"])
        XCTAssertEqual(records().count, 2)
    }

    func test_stored_timestamps_are_unique_to_the_millisecond() throws {
        insertList("自選")
        _ = try makeViewModel().confirmImport()
        let second = makeViewModel()
        second.toggleSelection(id: second.items[0].id)
        _ = try second.confirmImport()

        let times = records().compactMap { $0.value(forKey: "date") as? Date }.map(TradeImportViewModel.millis(of:))

        XCTAssertEqual(Set(times).count, 2)
    }

    func test_without_a_list_only_the_record_is_stored() throws {
        let submitted = try makeViewModel(listName: nil, lists: []).confirmImport()

        XCTAssertEqual(submitted, 1)
        XCTAssertEqual(records().count, 1)
    }
}
