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
    let publishedAt: Date
    var dateString: String {
        return formatDate(publishedAt)
    }
    
    let imageURL: URL?
    let url: String
    
    init(article: Article) {
        self.title = article.title ?? ""
        self.detail = article.description ?? ""
        self.publishedAt = article.publishedAt
        self.imageURL = URL(string: article.urlToImage ?? "")
        self.url = article.url ?? ""
    }
    
    func formatDate(_ date: Date) -> String {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "yyyy-MM-dd HH:mm"
        return dateformatter.string(from: date)
    }
}
