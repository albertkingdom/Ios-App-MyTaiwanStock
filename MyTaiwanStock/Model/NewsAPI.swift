//
//  NewsAPI.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//

import Foundation

struct NewsResult: Codable {
    var status: String
    var articles: [Article]
}

struct Article: Codable {
    var author: String
    var title: String
    var description: String
    var url: String
    var urlToImage: String
    var publishedAt: String
}

extension NewsResult {
    static func fetchNews(queryTitle: String, completion: @escaping (Result<NewsResult, Error>) -> Void ) {
        var urlComponents = URLComponents(string: "https://newsapi.org/v2/everything")!
        
        let querys = ["qInTitle": queryTitle, "apiKey": "a451f92024dc45ef90293b8a9e4a18df"]
        
        urlComponents.queryItems = querys.map({
            URLQueryItem(name: $0.key, value: $0.value)
        })
        
        let task = URLSession.shared.dataTask(with: urlComponents.url!) { data, response, error in
            if error != nil { return }
            
            let jsonDecoder = JSONDecoder()
            if let data = data {
                do {
                    let news = try jsonDecoder.decode(NewsResult.self, from: data)
                    //print("news, \(data)")
                    completion(.success(news))
                } catch {
                    completion(.failure(error))
                }
            }
            
        }
        task.resume()
    }
}
