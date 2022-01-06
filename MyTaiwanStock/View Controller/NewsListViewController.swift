//
//  NewsListViewController.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//

import UIKit

class NewsListViewController: UIViewController {
    
    var stockName: String?
    @IBOutlet weak var tableView: UITableView!
    var newsList: [Article] = []
    override func viewDidLoad() {
        tableView.dataSource = self
        tableView.delegate = self
        guard let stockName = stockName else { return }
        NewsResult.fetchNews(queryTitle: stockName) { result in
            switch result {
            case .success(let news):
                self.newsList = news.articles
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    
                    if self.newsList.count == 0, let stockName = self.stockName {
                        let alertC = UIAlertController(title: "新聞列表", message: "目前沒有\(String(describing: stockName))相關新聞!", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertC.addAction(okAction)
                        self.present(alertC, animated: true, completion: nil)
                    }
                }
            case .failure(let error):
                print("error, \(error.localizedDescription)")
            default: return
            }
        }
        //print("NewsListViewController stockName: \(stockName)")
    }
}

extension NewsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsList.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "newsCell", for: indexPath) as! NewsListTableViewCell
        cell.update(with: newsList[indexPath.row])
        
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wvc = storyboard?.instantiateViewController(withIdentifier: "webviewController") as! webViewController
        wvc.url = newsList[indexPath.row].url
        navigationController?.pushViewController(wvc, animated: true)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}
