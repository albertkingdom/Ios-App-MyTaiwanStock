//
//  NewsListViewController.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//

import UIKit

class NewsListViewController: UIViewController {
    var viewModel: NewsListViewModel!
    var stockName: String?
    @IBOutlet weak var tableView: UITableView!
    
    
    override func viewDidLoad() {
        tableView.dataSource = self
        tableView.delegate = self
        guard let stockName = stockName else { return }
        title = "\(stockName)新聞"
        
        viewModel = NewsListViewModel(stockName: stockName)
        
        bindViewModel()
        
        
        //print("NewsListViewController stockName: \(stockName)")
    }
    
    func bindViewModel() {
        viewModel.newsList.bind { [weak self] _ in
            self?.tableView.reloadData()
        }
        viewModel.isEmptyNews.bind { [weak self] isEmpty in
            if let isEmpty = isEmpty, isEmpty {
                let alertC = UIAlertController(title: "新聞列表", message: "目前沒有\( self?.stockName! ?? "")相關新聞!", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertC.addAction(okAction)
                self?.present(alertC, animated: true, completion: nil)
            }
        }
    }
}

extension NewsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.newsList.value?.count ?? 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "newsCell", for: indexPath) as! NewsListTableViewCell
        guard let cellViewModel = viewModel.newsList.value?[indexPath.row] else { return UITableViewCell() }
        
        cell.configure(with: cellViewModel)
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wvc = storyboard?.instantiateViewController(withIdentifier: "webviewController") as! webViewController
        guard let cellViewModel = viewModel.newsList.value?[indexPath.row] else { return }
        wvc.url = cellViewModel.url
        navigationController?.pushViewController(wvc, animated: true)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}
