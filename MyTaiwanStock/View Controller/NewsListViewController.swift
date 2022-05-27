//
//  NewsListViewController.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//
import Combine
import UIKit

class NewsListViewController: UIViewController {
    var subscription = Set<AnyCancellable>()
    var viewModel: NewsListViewModel!
    var stockName: String?
    @IBOutlet weak var tableView: UITableView!
    
    
    override func viewDidLoad() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor(red: 211/256, green: 211/256, blue: 211/256, alpha: 1)
        tableView.separatorStyle = .none
        guard let stockName = stockName else { return }
        title = "\(stockName)新聞"
        
        viewModel = NewsListViewModel(stockName: stockName)
        
        bindViewModel()
        
        
        //print("NewsListViewController stockName: \(stockName)")
    }
    
    func bindViewModel() {

        
        // 
        viewModel.newsList
            .combineLatest(viewModel.isLoading)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] data, isLoading in
                print("data \(data), isLoading \(isLoading)")
                self?.tableView.reloadData()
                
                if !isLoading && data.isEmpty {
                    self?.showAlert()
                }
            })
            .store(in: &subscription)
    }
    func showAlert() {
        let alertC = UIAlertController(title: "新聞列表", message: "目前沒有\( self.stockName ?? "")相關新聞!", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertC.addAction(okAction)
        self.present(alertC, animated: true, completion: nil)
    }
}

extension NewsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.newsList.value.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "newsCell", for: indexPath) as! NewsListTableViewCell
        //guard let cellViewModel = viewModel.newsList.value?[indexPath.row] else { return UITableViewCell() }
        let cellViewModel = viewModel.newsList.value[indexPath.row]
        cell.configure(with: cellViewModel)
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wvc = storyboard?.instantiateViewController(withIdentifier: "webviewController") as! webViewController
        //guard let cellViewModel = viewModel.newsList.value?[indexPath.row] else { return }
        let cellViewModel = viewModel.newsList.value[indexPath.row]
        wvc.url = cellViewModel.url
        navigationController?.pushViewController(wvc, animated: true)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}
