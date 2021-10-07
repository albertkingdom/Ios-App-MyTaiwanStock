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

extension StockInfo {
    static func fetchStockInfo(stockNo: String, dateStr: String = "20210930", completion: @escaping (Result<StockInfo,Error>) -> Void) {
        var urlComponents = URLComponents(string: "https://www.twse.com.tw/exchangeReport/STOCK_DAY")!
        
        urlComponents.queryItems = ["date":dateStr,"response":"json", "stockNo": stockNo].map({ URLQueryItem(name: $0.key, value: $0.value)
        })
        
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
    
    static func fetchTwoMonth(stockNo: String, completion: @escaping (_ alldata: [[String]]) -> Void) {
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
            //print("ok")
            //print("alldatas, \(alldatas)")
            completion(alldatas)
        }
    }
    
    
}
// TODO: make 2 request and combine the results
func dateFormat(date: Date) -> String {
    let dateFormatter = DateFormatter()

    dateFormatter.dateFormat = "yyyyMMdd"
    let datestr = dateFormatter.string(from: date)
    
    return datestr
}

func lastMonthDate() -> Date {
    var datecomponent = DateComponents()
    datecomponent.month = -1

    //print(datecomponent)
    let lastmonth = Calendar(identifier: .gregorian).date(byAdding: datecomponent, to: Date())!

    return lastmonth
}



