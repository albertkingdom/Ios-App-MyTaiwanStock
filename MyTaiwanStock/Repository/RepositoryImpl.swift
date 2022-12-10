//
//  RepositoryImpl.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/9/22.
//

import Foundation
import Combine

class RepositoryImpl: Repository {


    typealias StockData = OneDayStockInfo
    typealias CandleData = StockInfo
    
    var subscription = Set<AnyCancellable>()
    var localDBService = LocalDBService.shared
    var onLineDBService = OnlineDBService()
    
    func fetchOneDayStockInfo(stockList: [String], completionHandler: @escaping (Result<OneDayStockInfo, Error>) -> Void) {
        var urlComponents = URLComponents(string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp")!
        
        let stockListQuerys = stockList.map {"tse_\($0).tw"}.joined(separator: "|")
        
        // tse_2330.tw|tse_0050.tw
        urlComponents.queryItems = ["ex_ch":stockListQuerys,"json":"1"].map({ URLQueryItem(name: $0.key, value: $0.value)
        })
        
        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
            let jsonDecoder = JSONDecoder()
            if let data = data {
                do{
                    let stockInfo = try jsonDecoder.decode(OneDayStockInfo.self, from: data)
                
                    completionHandler(.success(stockInfo))
                }catch {
                    completionHandler(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    
    func fetchOneDayStockInfoCombine(stockList: [String]) -> Future<OneDayStockInfo, Error> {
        var urlComponents = URLComponents(string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp")!
        
        let stockListQuerys = stockList.map {"tse_\($0).tw"}.joined(separator: "|")
        
        // tse_2330.tw|tse_0050.tw
        urlComponents.queryItems = ["ex_ch":stockListQuerys,"json":"1"].map({ URLQueryItem(name: $0.key, value: $0.value)
        })
        return Future { promise in
            
            URLSession.shared.dataTaskPublisher(for: urlComponents.url!)
                .tryMap { data, response in
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                    return data
                }
                .decode(type: OneDayStockInfo.self, decoder: JSONDecoder())
                .sink { completion in

                    switch completion {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                    
                } receiveValue: { stockInfo in
                    promise(.success(stockInfo))
                }
                .store(in: &self.subscription)
        }
    }
    
    
    
    internal func fetchCandleData(stockNo: String, dateStr: String, completion: @escaping (Result<StockInfo, Error>) -> Void) {
        var urlComponents = URLComponents(string: "https://www.twse.com.tw/exchangeReport/STOCK_DAY")!
        
        urlComponents.queryItems = ["date":dateStr,"response":"json", "stockNo": stockNo]
            .map({ URLQueryItem(name: $0.key, value: $0.value)})
        
        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
            let jsonDecoder = JSONDecoder()
            if let data = data {
                do{
                    let stockInfo = try jsonDecoder.decode(StockInfo.self, from: data)
                
                    completion(.success(stockInfo))
                    
                }catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func fetchTwoMonthCandleData(stockNo: String, completion: @escaping ([[String]]) -> Void) {
        let group = DispatchGroup()
        let dateStr = [dateFormat(date: Date()), dateFormat(date: lastMonthDate())] //["20211005", "20210905"]
        var alldatas: [[String]] = []
        
        group.enter()
        StockInfo.fetchStockInfo(stockNo: stockNo, dateStr: dateStr[1]) { result in
            switch result {
            case .success(let stockInfo):
                //print("task1 \(stockInfo.data)")
                alldatas = stockInfo.data
            case .failure(let error):
                print("task1 failure, \(error)")
            }
            group.leave()
        }
        group.wait()
        group.enter()
        StockInfo.fetchStockInfo(stockNo: stockNo, dateStr: dateStr[0]) { result in
            switch result {
            case .success(let stockInfo):
                //print("task2 \(stockInfo.data)")
                alldatas.insert(contentsOf: stockInfo.data, at: alldatas.endIndex)
            case .failure(let error):
                print("task2 failure, \(error)")
            }
            group.leave()
        }
        group.notify(queue: DispatchQueue.main){
            completion(alldatas)
        }
    }

    
    func stockList() -> [List] {
        return localDBService.fetchAllListFromDB()
    }
    
    func historyList(with stockNo: String) -> [InvestHistory] {
        return localDBService.fetchHistoryFromDB(with: stockNo)
    }
    
    func fetchStockPriceFromDB(with stockNos: [String]) -> [StockNo] {
        return localDBService.fetchStockPriceFromDB(with: stockNos)
    }
    
    func saveList(with listName: String) -> List {
        guard let list = localDBService.saveNewListToDB(listName: listName) else { fatalError("unable to create list in db") }
        let _ = onLineDBService.uploadListToOnlineDB(listName: listName)
        
        return list
    }
    
    func saveStockNumber(with stockNumber: String, currentFollowingList: List) {
        localDBService.saveNewStockNumberToDB(stockNumber: stockNumber, currentFollowingList: currentFollowingList)
        guard let listName = currentFollowingList.name else { return }
        print("saveStockNumber listname \(listName)")
        onLineDBService.uploadNewStockNoToOnlineDB(stockNumber: stockNumber, listName: listName)
    }
    
    func saveNewRecord(stockNo: String, price: Float, amount: Int, reason: String, buyOrSellStatus: Int, date: Date) {
        localDBService.saveNewRecord(stockNo: stockNo, price: price, amount: amount, reason: reason, buyOrSellStatus: buyOrSellStatus, date: date)
        
        onLineDBService.uploadHistoryToOnlineDB(stockNo: stockNo, price: price, amount: amount, date: date, status: buyOrSellStatus)
    }
    
    func deleteStockNumber(stockNoObject: StockNo, listName: String, stockNumber: String) {
        localDBService.deleteStockNumberInDB(stockNoObject: stockNoObject)
       
        onLineDBService.deleteStockNoFromOnlineDB(stockNo: stockNumber, listName: listName)
    }
    
    func deleteHistory(historyObject: InvestHistory) {

        onLineDBService.deleteHistoryFromOnlineDB(where: historyObject)
        localDBService.deleteHistoryInDB(historyObject: historyObject)
    }
    
    func deleteList(list: List) {
        localDBService.deleteListFromDB(list: list)
        guard let listName = list.name else { return }
        onLineDBService.deleteListFromOnlineDB(listName: listName)
    }
    
    func updateStockNoInDBwithPrice(stockNos: [String], cellViewModels: [StockCellViewModel]) {
        localDBService.updateStockNoInDBwithPrice(stockNos: stockNos, cellViewModels: cellViewModels)
    }
    
    func getAllListAndStocksFromOnlineDBAndSaveToLocal(completion: (() -> Void)?) {
        onLineDBService.getAllListAndStocksFromOnlineDBAndSaveToLocal(completion: completion)
    }
    
    func getAllHistoryFromOnlineDBAndSaveToLocal() {
        onLineDBService.getAllHistoryFromOnlineDBAndSaveToLocal()
    }
}
