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
    var filteredItems: [String] = []
    var followingStockNoList: Set<String> = []
    var addNewStockToDB: ((String) -> ())!
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        // Do any additional setup after loading the view.
        navigationItem.title = "加入追蹤清單"
    }
    



}
extension AddStockNoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredItems.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockNoSuggestion", for: indexPath) as! AddStockTableViewCell
      
        let stockNameDetail = filteredItems[indexPath.row]
        let stockNumberString = String(filteredItems[indexPath.row].split(separator: " ")[0])

        cell.update(with: stockNameDetail)
        cell.followingStockNoList = followingStockNoList
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
        filteredItems = []
        tableView.reloadData()
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
            
            filteredItems = stockNoList.filter({ string in
                string.contains(searchTerm)
            })
        }
        
        tableView.reloadData()
    }
    
}
