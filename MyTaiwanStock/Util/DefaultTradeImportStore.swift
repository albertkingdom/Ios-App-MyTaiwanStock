//
//  DefaultTradeImportStore.swift
//  MyTaiwanStock
//

import Foundation

/// The real storage behind the screenshot import: the same local database and online sync
/// that manual entry uses, so imported records reach Firestore exactly like typed ones.
final class DefaultTradeImportStore: TradeImportStore {
    private let repository: NetworkServiceImpl
    private let localDB: LocalDBService

    init(repository: NetworkServiceImpl = NetworkServiceImpl(), localDB: LocalDBService = .shared) {
        self.repository = repository
        self.localDB = localDB
    }

    func existingTrades(stockNo: String) -> [ExistingTrade] {
        repository.historyList(with: stockNo).compactMap { record in
            guard let date = record.date else { return nil }
            return ExistingTrade(
                date: date, price: record.price, amount: Int(record.amount),
                side: record.status == 1 ? .sell : .buy)
        }
    }

    func usedTimestamps() -> Set<Int64> {
        Set(localDB.fetchAllHistoryDates().map(TradeImportViewModel.millis(of:)))
    }

    func saveRecord(stockNo: String, price: Float, amount: Int, side: TradeSide, date: Date) {
        repository.saveNewRecord(
            stockNo: stockNo, price: price, amount: amount, reason: "",
            buyOrSellStatus: side.rawValue, date: date)
    }

    func listContains(stockNo: String, listName: String) -> Bool {
        guard let list = repository.stockList().first(where: { $0.name == listName }) else { return false }
        return list.stockNos.contains { $0.stockNo == stockNo }
    }

    func addStock(stockNo: String, toList listName: String) {
        guard let list = repository.stockList().first(where: { $0.name == listName }) else { return }
        repository.saveStockNumber(with: stockNo, currentFollowingList: list)
    }
}
