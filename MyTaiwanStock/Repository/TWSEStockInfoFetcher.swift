//
//  TWSEStockInfoFetcher.swift
//  MyTaiwanStock
//
//  Shared TWSE fetch logic used by both the app and the widget extension.
//  Deliberately depends on nothing beyond Foundation so it stays cheap to
//  compile into memory-constrained extension targets.
//

import Foundation

struct TWSEStockInfoFetcher {
    /// Builds the quote request. Listed codes use `tse_`, OTC codes use `otc_`.
    static func requestURL(
        stockList: [String],
        lookup: StockMarketLookup = .current()
    ) -> URL? {
        guard var urlComponents = URLComponents(
            string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp"
        ) else { return nil }
        let stockListQuerys = lookup.exChannelQuery(forCodes: stockList)
        urlComponents.queryItems = ["ex_ch": stockListQuerys, "json": "1"].map({
            URLQueryItem(name: $0.key, value: $0.value)
        })
        return urlComponents.url
    }


    func fetchOneDayStockInfo(
        stockList: [String],
        completionHandler: @escaping (Result<OneDayStockInfo, Error>) -> Void
    ) {
        guard let url = Self.requestURL(stockList: stockList) else {
            completionHandler(.failure(URLError(.badURL)))
            return
        }

        let task = URLSession.shared.dataTask(with: url) {
            data,
            response,
            error in
            guard let data = data else {
                completionHandler(.failure(error ?? URLError(.badServerResponse)))
                return
            }
            do {
                let stockInfo = try JSONDecoder().decode(OneDayStockInfo.self, from: data)
                completionHandler(.success(stockInfo))
            } catch {
                completionHandler(.failure(error))
            }
        }

        task.resume()
    }
}
