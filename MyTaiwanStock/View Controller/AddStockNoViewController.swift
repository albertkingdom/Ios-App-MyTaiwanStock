//
//  AddStockNoViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/3/14.
//
import Combine
import UIKit

class AddStockNoViewController: UIViewController {
   
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    let viewModel = AddStockNoViewModel()
    
    var followingStockNoList: Set<String> = []
    var addNewStockToDB: ((String) -> ())!

    var listName: String?
    
    var subscription = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self

        // Do any additional setup after loading the view.
        guard let listName = listName else { return }

        navigationItem.title = "加入 \(listName) 清單"
        
        viewModel.followingStockNoList = followingStockNoList
        bindViewModel()
        
        setupSearchBarListener()
    }
    
    func bindViewModel() {

        viewModel.filteredAddStockCellViewModelsCombine
            .sink { [weak self] data in
                
                self?.tableView.reloadData()
            }.store(in: &subscription)
    }

    func setupSearchBarListener() {
        let publisher = NotificationCenter.default.publisher(for: UISearchTextField.textDidChangeNotification, object: searchBar.searchTextField)
        
        publisher
            .compactMap { notification in
                (notification.object as? UITextField)?.text
            }
            .sink { [weak self] str in
                self?.viewModel.searchText.send(str)
            }
            .store(in: &subscription)
    }

}
extension AddStockNoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.filteredAddStockCellViewModelsCombine.value.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockNoSuggestion", for: indexPath) as! AddStockTableViewCell
      
        let stockNameDetail = viewModel.filteredAddStockCellViewModelsCombine.value[indexPath.row]

        cell.configure(with: stockNameDetail)
        cell.addNewStockToDB = addNewStockToDB

        
        return cell
    }
  
    
}


