//
//  TradeImportViewModel.swift
//  MyTaiwanStock
//

import Foundation

struct ExistingTrade: Equatable {
    let date: Date
    let price: Float
    let amount: Int
    let side: TradeSide
}

/// What the import needs from local storage; the real one wraps `NetworkServiceImpl`.
protocol TradeImportStore {
    func existingTrades(stockNo: String) -> [ExistingTrade]
    /// Millisecond timestamps of every stored buy/sell record, across all stocks.
    func usedTimestamps() -> Set<Int64>
    func saveRecord(stockNo: String, price: Float, amount: Int, side: TradeSide, date: Date)
    func listContains(stockNo: String, listName: String) -> Bool
    func addStock(stockNo: String, toList listName: String)
}

enum TradePreviewStatus: Equatable {
    case importable
    case duplicate
    case incomplete
    case unsupported
}

struct TradePreviewItem: Equatable, Identifiable {
    let id: UUID
    var stockName: String
    var stockNo: String?
    var date: Date?
    var price: Float?
    var amount: Int?
    var side: TradeSide
    var tradeTypeText: String
    var isSupportedType: Bool
    var status: TradePreviewStatus
    var isSelected: Bool

    /// Whether every value needed to write the trade is present and valid.
    var isComplete: Bool { Self.isComplete(stockNo: stockNo, date: date, price: price, amount: amount) }

    static func isComplete(stockNo: String?, date: Date?, price: Float?, amount: Int?) -> Bool {
        guard stockNo != nil, date != nil,
              let price, price > 0,
              let amount, TradeImportViewModel.validShares.contains(amount)
        else { return false }
        return true
    }
}

/// The preview of a screenshot import: every recognized trade with a status, whether it is
/// selected, and the list the imported stocks go into. Nothing is written until the user confirms.
@MainActor
final class TradeImportViewModel {
    /// `InvestHistory.amount` is a 16-bit integer, so larger share counts cannot be stored.
    static let validShares = 1...Int(Int16.max)

    /// Only the view model changes items; the setter is internal so tests can build invalid states.
    var items: [TradePreviewItem]
    private(set) var selectedListName: String?
    let listNames: [String]

    private let isKnownCode: (String) -> Bool
    private let store: TradeImportStore

    init(
        trades: [ParsedTrade],
        resolver: StockNameResolver,
        isKnownCode: @escaping (String) -> Bool,
        store: TradeImportStore,
        listNames: [String],
        currentListName: String?
    ) {
        self.isKnownCode = isKnownCode
        self.store = store
        self.listNames = listNames
        self.selectedListName = currentListName.flatMap { listNames.contains($0) ? $0 : nil } ?? listNames.first
        self.items = trades.map { trade in
            TradePreviewItem(
                id: UUID(), stockName: trade.stockName, stockNo: resolver.resolve(name: trade.stockName),
                date: trade.date, price: trade.price, amount: trade.amount, side: trade.side,
                tradeTypeText: trade.tradeTypeText, isSupportedType: trade.isSupportedType,
                status: .incomplete, isSelected: false)
        }
        refreshStatuses(applyDefaultSelection: true)
    }

    // MARK: selection

    var isImportEnabled: Bool { items.contains { $0.isSelected } }

    func toggleSelection(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        // Incomplete and unsupported trades can never be selected.
        guard items[index].status == .importable || items[index].status == .duplicate else { return }
        items[index].isSelected.toggle()
    }

    // MARK: target list

    /// The list choices: every list, then "do not add to a list" (nil).
    var selectableLists: [String?] { listNames.map { Optional($0) } + [nil] }

    var showsNoListNotice: Bool { selectedListName == nil }

    func selectList(_ name: String?) {
        guard name == nil || listNames.contains(name!) else { return }
        selectedListName = name
    }

    // MARK: importing

    enum ImportError: Error, Equatable {
        /// A selected trade is not complete and valid; nothing was written.
        case invalidSelection
    }

    /// Writes the selected trades and returns how many were submitted for writing.
    ///
    /// Every selected trade is validated first and nothing is written when one is invalid, so a
    /// bad value can never leave a half-finished import behind. Writing happens on the main
    /// actor because the local store uses the view context. `saveNewRecord` reports no result,
    /// so the count is the number of records submitted, not confirmed saved.
    func confirmImport() throws -> Int {
        let selected = items.filter(\.isSelected)
        guard selected.allSatisfy({ $0.isComplete && isKnownCode($0.stockNo ?? "") && $0.isSupportedType }) else {
            throw ImportError.invalidSelection
        }

        var usedTimestamps = store.usedTimestamps()
        for item in selected {
            let date = Self.storedDate(for: item.date!, avoiding: &usedTimestamps)
            store.saveRecord(
                stockNo: item.stockNo!, price: item.price!, amount: item.amount!, side: item.side, date: date)
        }
        addImportedStocksToSelectedList(selected)
        return selected.count
    }

    private func addImportedStocksToSelectedList(_ selected: [TradePreviewItem]) {
        guard let listName = selectedListName else { return }
        var handled: Set<String> = []
        for stockNo in selected.compactMap(\.stockNo) where handled.insert(stockNo).inserted {
            if !store.listContains(stockNo: stockNo, listName: listName) {
                store.addStock(stockNo: stockNo, toList: listName)
            }
        }
    }

    /// Milliseconds since 1970 the way the online database derives a record's time, which is
    /// what identifies a record when it is deleted there.
    static func millis(of date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    /// The screenshot only has a calendar day. The record is stored at 12:00 Asia/Taipei that
    /// day, moved forward one millisecond at a time until no stored record and no earlier trade
    /// in this batch has the same millisecond timestamp.
    private static func storedDate(for day: Date, avoiding used: inout Set<Int64>) -> Date {
        let calendar = TaipeiCalendar.calendar
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        var candidateMillis = millis(of: noon)
        while true {
            let candidate = date(forMillis: candidateMillis)
            if !used.contains(millis(of: candidate)) {
                used.insert(millis(of: candidate))
                return candidate
            }
            candidateMillis += 1
        }
    }

    /// A date whose `millis(of:)` is exactly `value`, despite floating point rounding.
    private static func date(forMillis value: Int64) -> Date {
        let exact = Date(timeIntervalSince1970: Double(value) / 1000)
        if millis(of: exact) == value { return exact }
        return Date(timeIntervalSince1970: (Double(value) + 0.5) / 1000)
    }

    // MARK: editing

    func setStockNo(_ code: String, for id: UUID) {
        edit(id) { $0.stockNo = code.isEmpty ? nil : code }
    }

    func setPrice(_ price: Float?, for id: UUID) { edit(id) { $0.price = price } }
    func setAmount(_ amount: Int?, for id: UUID) { edit(id) { $0.amount = amount } }
    func setDate(_ date: Date?, for id: UUID) { edit(id) { $0.date = date } }
    func setSide(_ side: TradeSide, for id: UUID) { edit(id) { $0.side = side } }

    private func edit(_ id: UUID, _ change: (inout TradePreviewItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
        refreshStatuses(applyDefaultSelection: false)
    }

    // MARK: statuses

    private struct TradeKey: Hashable {
        let stockNo: String
        let day: DateComponents
        let price: Float
        let amount: Int
        let side: TradeSide
    }

    private static func key(stockNo: String, date: Date, price: Float, amount: Int, side: TradeSide) -> TradeKey {
        TradeKey(
            stockNo: stockNo,
            day: TaipeiCalendar.calendar.dateComponents([.year, .month, .day], from: date),
            price: price, amount: amount, side: side)
    }

    /// Recomputes every status. A trade whose status changed is selected when it became
    /// importable and deselected otherwise; a trade whose status is unchanged keeps its choice.
    private func refreshStatuses(applyDefaultSelection: Bool) {
        var existingKeys: [String: Set<TradeKey>] = [:]
        var batchKeys: Set<TradeKey> = []

        for index in items.indices {
            let item = items[index]
            let newStatus: TradePreviewStatus
            if !item.isSupportedType {
                newStatus = .unsupported
            } else if !item.isComplete || !isKnownCode(item.stockNo ?? "") {
                newStatus = .incomplete
            } else {
                let tradeKey = Self.key(
                    stockNo: item.stockNo!, date: item.date!, price: item.price!, amount: item.amount!, side: item.side)
                if existingKeys[item.stockNo!] == nil {
                    existingKeys[item.stockNo!] = Set(store.existingTrades(stockNo: item.stockNo!).map {
                        Self.key(stockNo: item.stockNo!, date: $0.date, price: $0.price, amount: $0.amount, side: $0.side)
                    })
                }
                let isDuplicate = existingKeys[item.stockNo!]!.contains(tradeKey) || batchKeys.contains(tradeKey)
                batchKeys.insert(tradeKey)
                newStatus = isDuplicate ? .duplicate : .importable
            }

            let changed = newStatus != item.status
            items[index].status = newStatus
            if applyDefaultSelection || changed {
                items[index].isSelected = newStatus == .importable
            }
        }
    }
}
