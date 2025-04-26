//
//  RepositoryImpl.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/9/22.
//

import Foundation
import Combine

class NetworkServiceImpl: NetworkService {


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
    
    
    func fetchOneDayStockInfoCombine(stockList: [String]) -> AnyPublisher<OneDayStockInfo, Error> {
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
                .retry(3)
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
        }.eraseToAnyPublisher()
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
    
    
    func fetchStockInfo(stockNo: String, dateStr: String = "20210930") async -> Result<StockInfo,Error> {
        var urlComponents = URLComponents(string: "https://www.twse.com.tw/exchangeReport/STOCK_DAY")!
        
        urlComponents.queryItems = ["date":dateStr,"response":"json", "stockNo": stockNo].map({ URLQueryItem(name: $0.key, value: $0.value)
        })
        do {
            let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
            let jsonDecoder = JSONDecoder()
            let stockInfo = try jsonDecoder.decode(StockInfo.self, from: data)
            return .success(stockInfo)
        } catch let error {
            return .failure(error)
        }
    }
    
    func fetchTwoMonthCandleData(stockNo: String) async -> [[String]] {
        var orderedData: [String: [[String]]] = [:]
        let dateStrs = [
            dateFormat(date: startDateOfMonth(diff: -2)),
            dateFormat(date: startDateOfMonth(diff: -1)),
            dateFormat(date: Date()),
        ] //[, "20210905", "20211005"]
        var alldatas: [[String]] = []
        for dateStr in dateStrs {
            
            let result = await fetchStockInfo(stockNo: stockNo, dateStr: dateStr)
            
            switch result {
            case .success(let stockInfo):
                orderedData[dateStr] = stockInfo.data
            case .failure(let error):
                print("failure, \(error)")
            }
            
        }
        alldatas = dateStrs.compactMap { orderedData[$0] }.flatMap { $0 }
        
        return alldatas
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

    func fetchStockDividend() -> [StockDividend] {
        return localDBService.fetchAllStockDividend()
    }
    func fetchStockDividend(with stockNo: String) -> [StockDividend] {
        return localDBService.fetchAllStockDividend(with: stockNo)
    }
    func fetchCashDividend() -> [CashDividend] {
        return localDBService.fetchAllCashDividend()
    }
    func fetchCashDividend(with stockNo: String) -> [CashDividend] {
        return localDBService.fetchAllCashDividend(with: stockNo)
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
    
    func saveStockDividend(stockNo: String, amount: Int, date: Date) {
        localDBService.saveStockDividend(stockNo: stockNo, amount: amount, date: date)
    }
    
    func saveCashDividend(stockNo: String, amount: Int, date: Date) {
        localDBService.saveCashDividend(stockNo: stockNo, amount: amount, date: date)
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
    // 發送ID和FCM令牌到server(server要記錄每個裝置目前的badge count)
    func sendDeviceIdToServer(deviceId: String, token: String) {
        let url = URL(string: "http://albertkingdom.ddns.net:3000/register-device")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = ["deviceId": deviceId, "token": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending device ID to server: \(error.localizedDescription)")
                return
            }
            print("Successfully sent device ID to server")
        }
        task.resume()
    }
    
    func sendDevice(deviceId: String, token: String) async {
        let url = URL(string: "http://albertkingdom.ddns.net:3000/register-device")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = ["deviceId": deviceId, "token": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("Successfully sent device ID to server")
                }
            }
        } catch let error {
            print("Error sending device ID to server: \(error.localizedDescription)")
        }
    }

    private func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "yyyyMMdd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }
    
    private func startDateOfMonth(diff: Int) -> Date {
        var datecomponent = DateComponents()
        datecomponent.month = diff
        
        //print(datecomponent)
        let lastmonth = Calendar(identifier: .gregorian).date(byAdding: datecomponent, to: Date())!
        
        return lastmonth
    }
}
