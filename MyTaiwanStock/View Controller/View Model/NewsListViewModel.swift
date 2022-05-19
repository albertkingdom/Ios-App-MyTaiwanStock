//
//  NewsListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/17/22.
//

import Foundation

class NewsListViewModel {
    var newsList = Observable<[NewsListCellViewModel]>([])
    var stockName: String?
    var isEmptyNews = Observable<Bool>(false)
    
    init(stockName: String) {
        self.stockName = stockName
        fetchNews()
    }
    
    func fetchNews() {
        NewsResult.fetchNews(queryTitle: stockName!) { [weak self] result in
            switch result {
            case .success(let news):
                self?.newsList.value = news.articles.map({ article in
                    NewsListCellViewModel(article: article)
                })
                
               
                    
                    
                if news.articles.count == 0, let _ = self?.stockName {
                    self?.isEmptyNews.value = true
                }
                
            case .failure(let error):
                print("error, \(error.localizedDescription)")
                self?.isEmptyNews.value = true
            default: return
            }
        }
    }
}
