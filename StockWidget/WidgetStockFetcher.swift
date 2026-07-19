//
//  WidgetStockFetcher.swift
//  StockWidgetExtension
//

import Foundation

struct WidgetStockFetcher {
    func fetchOneDayStockInfo(
        stockList: [String],
        completionHandler: @escaping (Result<OneDayStockInfo, Error>) -> Void
    ) {
        var urlComponents = URLComponents(
            string: "https://mis.twse.com.tw/stock/api/getStockInfo.jsp"
        )!

        let stockListQuerys = stockList.map { "tse_\($0).tw" }.joined(separator: "|")

        urlComponents.queryItems = ["ex_ch": stockListQuerys, "json": "1"].map({
            URLQueryItem(name: $0.key, value: $0.value)
        })

        let task = URLSession.shared.dataTask(with: urlComponents.url!) {
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
