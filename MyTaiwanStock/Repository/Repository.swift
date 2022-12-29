//
//  Repository.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/9/22.
//

import Foundation
import Combine

protocol Repository {
    associatedtype StockData
    associatedtype CandleData
    
    // realtime stock info
    func fetchOneDayStockInfo(stockList: [String], completionHandler: @escaping (Result<StockData,Error>) -> Void)
    
    func fetchOneDayStockInfoCombine(stockList: [String]) -> Future<StockData, Error>
    
    // get candle stick data
    func fetchCandleData(stockNo: String, dateStr: String, completion: @escaping (Result<CandleData, Error>) -> Void)
    
    // 2 month candle stick data
    func fetchTwoMonthCandleData(stockNo: String, completion: @escaping (_ alldata: [[String]]) -> Void)
    
    // fetch saved List
    func stockList() -> [List]
    
    // fetch saved history
    func historyList(with stockNo: String) -> [InvestHistory]
    
    // fetch saved stockPrice
    func fetchStockPriceFromDB(with stockNos: [String]) -> [StockNo]
    
    // fetch saved stockDividend
    func fetchStockDividend() -> [StockDividend]
    
    func fetchStockDividend(with stockNo: String) -> [StockDividend]
    
    // fetch saved cash Dividend
    func fetchCashDividend() -> [CashDividend]
    
    func fetchCashDividend(with stockNo: String) -> [CashDividend]
    
    // save new list
    func saveList(with listName: String) -> List
    
    // save new stock no.
    func saveStockNumber(with stockNumber: String, currentFollowingList: List)
    
    // save new investing record
    func saveNewRecord(stockNo: String, price: Float, amount: Int, reason: String, buyOrSellStatus: Int, date: Date)
    
    // save 股票股利
    func saveStockDividend(stockNo: String, amount: Int, date: Date)
    
    // save 現金股利
    func saveCashDividend(stockNo: String, amount: Int, date: Date)
    
    // delete stock number
    func deleteStockNumber(stockNoObject: StockNo, listName: String, stockNumber: String)
    
    // delete history
    func deleteHistory(historyObject: InvestHistory)
    
    // delete list
    func deleteList(list: List)
    
    // update
    func updateStockNoInDBwithPrice(stockNos: [String], cellViewModels: [StockCellViewModel])
    
    // get all list from online DB
    func getAllListAndStocksFromOnlineDBAndSaveToLocal(completion: (() -> Void)?)
    
    // get all history from online DB
    func getAllHistoryFromOnlineDBAndSaveToLocal()
    
}
