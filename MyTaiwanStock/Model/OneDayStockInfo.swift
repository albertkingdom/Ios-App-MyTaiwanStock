//
//  OneDayStockInfo.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import Foundation

struct OneDayStockInfo: Codable {
    var msgArray: [OneDayStockInfoDetail]
}

struct OneDayStockInfoDetail: Codable {
    var c: String //代號
    var o: String //開盤
    var l: String //最低
    var h: String //最高
    var tv: String //當盤成交量
    var nf: String //公司全名
    var z: String //當盤成交價
    var n: String //公司簡稱
}

extension OneDayStockInfo {
    static func fetchOneDayStockInfo(stockList: [StockList],completion: @escaping (Result<OneDayStockInfo,Error>) -> Void) {
        var urlComponents = URLComponents(string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp")!
        
        
        let stockListQuerys = stockList.map {"tse_\($0.stockNo).tw"}.joined(separator: "|")
        
        // tse_2330.tw|tse_0050.tw
        urlComponents.queryItems = ["ex_ch":stockListQuerys,"json":"1"].map({ URLQueryItem(name: $0.key, value: $0.value)
        })
        
        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
            let jsonDecoder = JSONDecoder()
            if let data = data {
                do{
                    let stockInfo = try jsonDecoder.decode(OneDayStockInfo.self, from: data)
                
                    completion(.success(stockInfo))
                    
                }catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
}
