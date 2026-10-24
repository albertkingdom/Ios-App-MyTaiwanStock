//
//  StockInfo.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import Foundation

struct StockInfo: Codable {
    var stat: String
    var date: String
    var title: String
    var fields: [String]
    var data: [[String]]
    var notes: [String]
    

    
}

//extension StockInfo {
//    static func fetchStockInfo(stockNo: String, dateStr: String = "20210930", completion: @escaping (Result<StockInfo,Error>) -> Void) {
//        var urlComponents = URLComponents(string: "https://www.twse.com.tw/exchangeReport/STOCK_DAY")!
//        
//        urlComponents.queryItems = ["date":dateStr,"response":"json", "stockNo": stockNo].map({ URLQueryItem(name: $0.key, value: $0.value)
//        })
//        
//        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
//            let jsonDecoder = JSONDecoder()
//            if let data = data {
//                do{
//                    let stockInfo = try jsonDecoder.decode(StockInfo.self, from: data)
//                    
//                    completion(.success(stockInfo))
//                    
//                }catch {
//                    completion(.failure(error))
//                }
//            }
//        }
//        
//        task.resume()
//    }
//    
//    static func fetchTwoMonth(stockNo: String, completion: @escaping (_ alldata: [[String]]) -> Void) {
//        var orderedData: [String: [[String]]] = [:]
//        let semaphore = DispatchSemaphore(value: 1)
//        let group = DispatchGroup()
//        let dateStrs = [
//            dateFormat(date: startDateOfMonth(diff: -2)),
//            dateFormat(date: startDateOfMonth(diff: -1)),
//            dateFormat(date: Date()),
//        ] //[, "20210905", "20211005"]
//        var alldatas: [[String]] = []
//        for dateStr in dateStrs {
//            group.enter()
//            
//            StockInfo.fetchStockInfo(stockNo: stockNo, dateStr: dateStr) { result in
//                defer { group.leave() }
//                switch result {
//                case .success(let stockInfo):
//                    semaphore.wait()
//                    orderedData[dateStr] = stockInfo.data
//                    semaphore.signal()
//                case .failure(let error):
//                    print("task1 failure, \(error)")
//                }
//            }
//        }
//        group.wait()
//        alldatas = dateStrs.compactMap { orderedData[$0] }.flatMap { $0 }
//        group.notify(queue: DispatchQueue.main){
//            //print("ok")
//            //print("alldatas, \(alldatas)")
//            completion(alldatas)
//        }
//    }
//    
//}
    
    
    
    
    

