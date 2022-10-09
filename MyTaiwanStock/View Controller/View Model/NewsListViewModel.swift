//
//  NewsListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/17/22.
//
import Combine
import Foundation

class NewsListViewModel {

    var newsList = CurrentValueSubject<[NewsListCellViewModel], Never>([])
    var stockName: String?
    var isLoading = CurrentValueSubject<Bool, Never>(true)
    
    init(stockName: String) {
        self.stockName = stockName
        fetchNews()
    }
    
    func fetchNews() {
        NewsResult.fetchNews(queryTitle: stockName!) { [weak self] result in
            switch result {
            case .success(let news):

                let newsCellData = news.articles.map({ article in
                    NewsListCellViewModel(article: article)
                })
                self?.newsList.send(newsCellData)
                self?.isLoading.send(false)
                
            case .failure(let error):
                print("error, \(error.localizedDescription)")
                self?.isLoading.send(false)

            }
        }
    }
}
