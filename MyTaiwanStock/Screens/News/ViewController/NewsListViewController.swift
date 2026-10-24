//
//  NewsListViewController.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//
import Combine
import UIKit

class NewsListViewController: UIViewController {
    enum Section {
        case main
    }
    struct Item: Hashable {
        let viewModel: NewsListCellViewModel
        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.viewModel.url == rhs.viewModel.url
        }
    }
    var subscription = Set<AnyCancellable>()
    var viewModel: NewsListViewModel!
    var stockName: String?
    @IBOutlet weak var tableView: UITableView!
    
    private lazy var dataSource: UITableViewDiffableDataSource<Section, Item> = {
        let dataSource = UITableViewDiffableDataSource<Section, Item>(
            tableView: tableView) { tableView, indexPath, itemIdentifier in
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "newsCell2", for: indexPath) as? NewsListTableViewCell2 else {
                    fatalError("Cannot create new cell")
                }
                cell.configure(with: itemIdentifier.viewModel)
              cell.selectionStyle = .none
              return cell
            }
        return dataSource
    }()
    
    override func viewDidLoad() {
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.separatorStyle = .none
        guard let stockName = stockName else { return }
        title = "\(stockName)新聞"
        
        viewModel = NewsListViewModel(stockName: stockName)
        applySnapShot(animate: false) // Apply an initial empty snapshot without animation
        bindViewModel()
        
}
    
    func bindViewModel() {
        viewModel.newsList
            .combineLatest(viewModel.isLoading)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] data, isLoading in
                print("data \(data), isLoading \(isLoading)")
                
                if !isLoading && data.isEmpty {
                    self?.showAlert()
                }
                let animate = !isLoading
                self?.applySnapShot(animate: animate)
            })
            .store(in: &subscription)
    }
    func showAlert() {
        let alertC = UIAlertController(title: "新聞列表", message: "目前沒有\( self.stockName ?? "")相關新聞!", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertC.addAction(okAction)
        self.present(alertC, animated: true, completion: nil)
    }
    func applySnapShot(animate: Bool = true) {
        var snapShot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapShot.appendSections([.main])
        let items = viewModel.newsList.value.map { Item(viewModel: $0) }
        snapShot.appendItems(items)
        dataSource.apply(snapShot, animatingDifferences: true)
    }
}

extension NewsListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wvc = storyboard?.instantiateViewController(withIdentifier: "webviewController") as! webViewController
        let cellViewModel = viewModel.newsList.value[indexPath.row]
        wvc.url = cellViewModel.url
        navigationController?.pushViewController(wvc, animated: true)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300
    }
}
