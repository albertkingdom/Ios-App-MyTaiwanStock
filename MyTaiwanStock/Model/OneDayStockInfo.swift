//
//  OneDayStockInfo.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//
import Combine
import Foundation

struct OneDayStockInfo: Codable {
    var msgArray: [OneDayStockInfoDetail]
}

struct OneDayStockInfoDetail: Codable {
    var stockNo: String //代號
    var open: String //開盤
    var low: String //最低
    var high: String //最高
    var fullName: String //公司全名
    var current: String //當盤成交價
    var shortName: String //公司簡稱
    var yesterDayPrice: String //昨日收盤
    
    enum CodingKeys: String, CodingKey {
        case stockNo = "c"
        case open = "o"
        case low = "l"
        case high = "h"
        case fullName = "nf"
        case current = "z"
        case shortName = "n"
        case yesterDayPrice = "y"
    }
}

extension OneDayStockInfo {
    static var subscription = Set<AnyCancellable>()
    static var priceList: [OneDayStockInfoDetail] = []
    static func fetchOneDayStockInfo(stockList: [String],completion: @escaping (Result<OneDayStockInfo,Error>) -> Void) {
        var urlComponents = URLComponents(string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp")!
        
        
//        let stockListQuerys = stockList.map {"tse_\($0.stockNo!).tw"}.joined(separator: "|")
        let stockListQuerys = stockList.map {"tse_\($0).tw"}.joined(separator: "|")
        //print("stockListQuerys, \(stockListQuerys)")
        // tse_2330.tw|tse_0050.tw
        urlComponents.queryItems = ["ex_ch":stockListQuerys,"json":"1"].map({ URLQueryItem(name: $0.key, value: $0.value)
        })
        
        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
            let jsonDecoder = JSONDecoder()
            if let data = data {
                do{
                    let stockInfo = try jsonDecoder.decode(OneDayStockInfo.self, from: data)
                    //print("stockInfo, \(stockInfo)")
                    priceList = stockInfo.msgArray
                    completion(.success(stockInfo))
                    
                }catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    static func fetchOneDayStockInfoCombine(stockList: [String]) -> Future<OneDayStockInfo, Error> {
        print("fetchOneDayStockInfoCombine")
        var urlComponents = URLComponents(string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp")!
        
        
//        let stockListQuerys = stockList.map {"tse_\($0.stockNo!).tw"}.joined(separator: "|")
        let stockListQuerys = stockList.map {"tse_\($0).tw"}.joined(separator: "|")
        //print("stockListQuerys, \(stockListQuerys)")
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
                print(completion)
                switch completion {
                case .failure(let error):
                    promise(.failure(error))
                case .finished:
                    break
                }
               
            } receiveValue: { stockInfo in
                print("stockInfo \(stockInfo)")
                priceList = stockInfo.msgArray
                promise(.success(stockInfo))
            }
            .store(in: &subscription)

        }
            
    }
}
