//
//  AddStockNoViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/3/14.
//

import UIKit

class AddStockNoViewController: UIViewController {
   
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    let viewModel = AddStockNoViewModel()
    
    var followingStockNoList: Set<String> = []
    var addNewStockToDB: ((String) -> ())!

    var listName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        // Do any additional setup after loading the view.
        guard let listName = listName else { return }

        navigationItem.title = "加入 \(listName) 清單"
        
        viewModel.followingStockNoList = followingStockNoList
        bindViewModel()
    }
    
    func bindViewModel() {
        viewModel.filteredAddStockCellViewModels.bind { [weak self] _ in
            self?.tableView.reloadData()
        }
    }


}
extension AddStockNoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.filteredAddStockCellViewModels.value?.count ?? 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockNoSuggestion", for: indexPath) as! AddStockTableViewCell
      
        guard let stockNameDetail = viewModel.filteredAddStockCellViewModels.value?[indexPath.row] else { return UITableViewCell() }
        

        cell.configure(with: stockNameDetail)
        cell.addNewStockToDB = addNewStockToDB

        
        return cell
    }
  
    
}

extension AddStockNoViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let searchTerm = searchBar.text ?? ""
        search(searchTerm)
        searchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {

        viewModel.filteredAddStockCellViewModels.value = []

        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
  
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        search(searchText)
    }
    func search(_ searchTerm: String) {
        if !searchTerm.isEmpty {
            viewModel.searchStockNos(with: searchTerm)
        }
        
    }
    
}
