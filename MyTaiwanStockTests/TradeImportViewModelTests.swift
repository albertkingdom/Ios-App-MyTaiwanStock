//
//  TradeImportViewModelTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class FakeTradeImportStore: TradeImportStore {
    var existing: [String: [ExistingTrade]] = [:]
    var timestamps: Set<Int64> = []
    var lists: [String: Set<String>] = [:]
    private(set) var saved: [(stockNo: String, price: Float, amount: Int, side: TradeSide, date: Date)] = []
    private(set) var addedStocks: [(stockNo: String, listName: String)] = []

    func existingTrades(stockNo: String) -> [ExistingTrade] { existing[stockNo] ?? [] }
    func usedTimestamps() -> Set<Int64> { timestamps }
    func saveRecord(stockNo: String, price: Float, amount: Int, side: TradeSide, date: Date) {
        saved.append((stockNo, price, amount, side, date))
    }
    func listContains(stockNo: String, listName: String) -> Bool { lists[listName]?.contains(stockNo) ?? false }
    func addStock(stockNo: String, toList listName: String) {
        addedStocks.append((stockNo, listName))
        lists[listName, default: []].insert(stockNo)
    }
}

@MainActor
final class TradeImportViewModelTests: XCTestCase {

    private let entries = [
        StockListEntry(code: "0050", name: "元大台灣50", market: .tse),
        StockListEntry(code: "2344", name: "華邦電", market: .tse),
        StockListEntry(code: "2330", name: "台積電", market: .tse),
        StockListEntry(code: "2379", name: "瑞昱", market: .tse),
    ]
    private var store: FakeTradeImportStore!

    override func setUp() {
        super.setUp()
        store = FakeTradeImportStore()
    }

    private func taipei(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        TaipeiCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func parsed(
        _ name: String = "元大台灣50", price: Float? = 112.55, amount: Int? = 5,
        date: Date? = nil, side: TradeSide = .buy, type: String = "盤中零股買進", supported: Bool = true
    ) -> ParsedTrade {
        ParsedTrade(
            stockName: name, date: date ?? taipei(2026, 9, 30), price: price, amount: amount,
            side: side, tradeTypeText: type, isSupportedType: supported)
    }

    private func makeViewModel(
        _ trades: [ParsedTrade], lists: [String] = ["我的清單"], current: String? = "我的清單"
    ) -> TradeImportViewModel {
        let resolver = StockNameResolver(entries: entries)
        let codes = Set(entries.map(\.code))
        return TradeImportViewModel(
            trades: trades, resolver: resolver, isKnownCode: { codes.contains($0) },
            store: store, listNames: lists, currentListName: current)
    }

    private func status(_ viewModel: TradeImportViewModel, _ index: Int = 0) -> TradePreviewStatus {
        viewModel.items[index].status
    }

    // MARK: statuses

    func test_complete_trade_is_importable_and_selected() {
        let viewModel = makeViewModel([parsed()])

        XCTAssertEqual(status(viewModel), .importable)
        XCTAssertTrue(viewModel.items[0].isSelected)
        XCTAssertEqual(viewModel.items[0].stockNo, "0050")
    }

    func test_existing_record_makes_a_duplicate_that_is_not_selected_but_can_be_selected() {
        // Stored with a time of day, as a manual entry would be.
        store.existing["0050"] = [ExistingTrade(date: taipei(2026, 9, 30, hour: 14, minute: 3), price: 112.55, amount: 5, side: .buy)]
        let viewModel = makeViewModel([parsed()])

        XCTAssertEqual(status(viewModel), .duplicate)
        XCTAssertFalse(viewModel.items[0].isSelected)

        viewModel.toggleSelection(id: viewModel.items[0].id)

        XCTAssertTrue(viewModel.items[0].isSelected)
    }

    func test_duplicate_key_examples() {
        store.existing["0050"] = [ExistingTrade(date: taipei(2026, 9, 30), price: 112.55, amount: 5, side: .buy)]
        let viewModel = makeViewModel([
            parsed(),                                  // same trade
            parsed(side: .sell, type: "盤中零股賣出"),    // other direction
            parsed(amount: 6),                         // other shares
            parsed(date: taipei(2026, 10, 1)),         // other day
        ])

        XCTAssertEqual(viewModel.items.map(\.status), [.duplicate, .importable, .importable, .importable])
    }

    func test_same_trade_twice_in_a_batch_marks_the_second_as_duplicate() {
        let viewModel = makeViewModel([parsed(), parsed()])

        XCTAssertEqual(viewModel.items.map(\.status), [.importable, .duplicate])
        XCTAssertEqual(viewModel.items.map(\.isSelected), [true, false])
    }

    func test_incomplete_trades_cannot_be_selected() {
        let viewModel = makeViewModel([
            parsed("不存在的股票"), parsed(price: nil), parsed(amount: nil), parsed(price: 0),
            ParsedTrade(stockName: "元大台灣50", date: nil, price: 1, amount: 1, side: .buy, tradeTypeText: "盤中零股買進", isSupportedType: true),
        ])

        XCTAssertEqual(Set(viewModel.items.map(\.status)), [.incomplete])
        XCTAssertTrue(viewModel.items.allSatisfy { !$0.isSelected })

        viewModel.toggleSelection(id: viewModel.items[0].id)

        XCTAssertFalse(viewModel.items[0].isSelected)
    }

    func test_share_count_must_be_between_1_and_32767() {
        let amounts = [0, 1, 32767, 32768, 33000]
        let viewModel = makeViewModel(amounts.map { parsed(amount: $0) })

        XCTAssertEqual(viewModel.items.map(\.status), [.incomplete, .importable, .importable, .incomplete, .incomplete])
    }

    func test_unsupported_type_is_not_selectable() {
        let viewModel = makeViewModel([parsed("元大台灣50", type: "融資買進", supported: false)])

        XCTAssertEqual(status(viewModel), .unsupported)
        viewModel.toggleSelection(id: viewModel.items[0].id)
        XCTAssertFalse(viewModel.items[0].isSelected)
    }

    func test_status_priority_is_unsupported_then_incomplete_then_duplicate() {
        store.existing["0050"] = [ExistingTrade(date: taipei(2026, 9, 30), price: 112.55, amount: 5, side: .buy)]
        let viewModel = makeViewModel([
            parsed("不存在的股票", type: "融資買進", supported: false), // unsupported and incomplete
            parsed(amount: 33000),                                    // incomplete
            parsed(),                                                 // duplicate
        ])

        XCTAssertEqual(viewModel.items.map(\.status), [.unsupported, .incomplete, .duplicate])
    }

    // MARK: editing

    func test_entering_an_unknown_stock_number_keeps_the_trade_incomplete() {
        let viewModel = makeViewModel([parsed("不存在的股票")])
        let id = viewModel.items[0].id

        viewModel.setStockNo("23", for: id)

        XCTAssertEqual(status(viewModel), .incomplete)
        XCTAssertFalse(viewModel.items[0].isSelected)
    }

    func test_entering_a_listed_stock_number_makes_it_importable_and_selects_it() {
        let viewModel = makeViewModel([parsed("不存在的股票")])

        viewModel.setStockNo("2344", for: viewModel.items[0].id)

        XCTAssertEqual(status(viewModel), .importable)
        XCTAssertTrue(viewModel.items[0].isSelected)
        XCTAssertEqual(viewModel.items[0].stockNo, "2344")
    }

    func test_edit_that_creates_a_duplicate_deselects_the_trade() {
        store.existing["0050"] = [ExistingTrade(date: taipei(2026, 9, 30), price: 112.55, amount: 5, side: .buy)]
        let viewModel = makeViewModel([parsed(amount: 6)])
        XCTAssertTrue(viewModel.items[0].isSelected)

        viewModel.setAmount(5, for: viewModel.items[0].id)

        XCTAssertEqual(status(viewModel), .duplicate)
        XCTAssertFalse(viewModel.items[0].isSelected)
    }

    func test_filling_in_the_missing_date_makes_the_trade_selectable() {
        let viewModel = makeViewModel([
            ParsedTrade(stockName: "元大台灣50", date: nil, price: 112.55, amount: 5, side: .buy, tradeTypeText: "盤中零股買進", isSupportedType: true),
        ])
        XCTAssertEqual(status(viewModel), .incomplete)

        viewModel.setDate(taipei(2026, 9, 30), for: viewModel.items[0].id)

        XCTAssertEqual(status(viewModel), .importable)
        XCTAssertTrue(viewModel.items[0].isSelected)
    }

    func test_editing_an_earlier_trade_updates_later_duplicates() {
        let viewModel = makeViewModel([parsed(), parsed()])
        XCTAssertEqual(viewModel.items.map(\.status), [.importable, .duplicate])

        viewModel.setAmount(7, for: viewModel.items[0].id)

        XCTAssertEqual(viewModel.items.map(\.status), [.importable, .importable])
        XCTAssertEqual(viewModel.items.map(\.isSelected), [true, true])
    }

    // MARK: import button

    func test_import_is_enabled_only_while_something_is_selected() {
        let viewModel = makeViewModel([parsed()])
        XCTAssertTrue(viewModel.isImportEnabled)

        viewModel.toggleSelection(id: viewModel.items[0].id)

        XCTAssertFalse(viewModel.isImportEnabled)
    }

    // MARK: target list

    func test_default_list_is_the_current_list() {
        let viewModel = makeViewModel([parsed()], lists: ["A", "B"], current: "B")

        XCTAssertEqual(viewModel.selectedListName, "B")
        XCTAssertEqual(viewModel.selectableLists, ["A", "B", nil])
        XCTAssertFalse(viewModel.showsNoListNotice)
    }

    func test_without_any_list_the_default_is_no_list() {
        let viewModel = makeViewModel([parsed()], lists: [], current: nil)

        XCTAssertNil(viewModel.selectedListName)
        XCTAssertEqual(viewModel.selectableLists, [nil])
        XCTAssertTrue(viewModel.showsNoListNotice)
    }

    func test_choosing_no_list_shows_the_notice() {
        let viewModel = makeViewModel([parsed()], lists: ["A"], current: "A")

        viewModel.selectList(nil)

        XCTAssertNil(viewModel.selectedListName)
        XCTAssertTrue(viewModel.showsNoListNotice)
    }
}
