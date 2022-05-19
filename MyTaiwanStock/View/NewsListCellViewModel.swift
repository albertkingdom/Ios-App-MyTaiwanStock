//
//  NewsListCellViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/17/22.
//

import Foundation

struct NewsListCellViewModel {
    let title: String
    let detail: String
    let publishedAt: String
    var dateString: String {
        return formatDate(publishedAt)
    }
    
    let imageURL: URL?
    let url: String
    
    init(article: Article) {
        self.title = article.title
        self.detail = article.description
        self.publishedAt = article.publishedAt
        self.imageURL = URL(string: article.urlToImage)
        self.url = article.url
    }
    
    func formatDate(_ dateStr: String) -> String {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let date = dateformatter.date(from: dateStr)

        dateformatter.dateFormat = "yyyy-MM-dd"
        return dateformatter.string(from: date!)
    }
}
