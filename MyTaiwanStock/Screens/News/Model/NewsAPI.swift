//
//  NewsAPI.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//

import Foundation

struct NewsResult: Codable {
    var status: String
    var totalResults: Int
    var articles: [Article]
}

struct Source: Codable {
    var id: String?
    var name: String?
}

struct Article: Codable {
    var source: Source
    var author: String?
    var title: String?
    var description: String?
    var url: String?
    var urlToImage: String?
    var publishedAt: Date
    var content: String?
}

enum NewsAPIError: Error {
    case invalidURL
    case noData
    case decodingError(String)
    case unknown(Error)
}

final class NewsAPIClient {
    static let shared = NewsAPIClient()
    func fetchNews(queryTitle: String, completion: @escaping (Result<NewsResult, Error>) -> Void ) {
        var urlComponents = URLComponents(string: "https://newsapi.org/v2/everything")!
        guard let apiKey = Bundle.main.infoDictionary?["NEWS_API_KEY"] as? String else {
            fatalError("API key not found in Info.plist")
        }
        let querys = ["qInTitle": queryTitle, "apiKey": apiKey]
        
        urlComponents.queryItems = querys.map({
            URLQueryItem(name: $0.key, value: $0.value)
        })
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
                return
            }
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .iso8601
            do {
                let news = try jsonDecoder.decode(NewsResult.self, from: data)
                completion(.success(news))
            } catch {
                let errorMessage = NewsAPIClient.getDecodingErrorMessage(error)
                completion(.failure(NewsAPIError.decodingError(errorMessage)))
            }
        }
        task.resume()
    }
    
    private static func getDecodingErrorMessage(_ error: Error) -> String {
         switch error {
         case DecodingError.keyNotFound(let key, let context):
             return "Key '\(key.stringValue)' not found: \(context.debugDescription)"
         case DecodingError.typeMismatch(let type, let context):
             return "Type '\(type)' mismatch: \(context.debugDescription)"
         case DecodingError.valueNotFound(let type, let context):
             return "Value '\(type)' not found: \(context.debugDescription)"
         default:
             return error.localizedDescription
         }
     }
}
