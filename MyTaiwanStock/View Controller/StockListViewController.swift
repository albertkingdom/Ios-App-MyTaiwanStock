//
//  ViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import UIKit

class StockListViewController: UIViewController {
    var onedayStockInfo: [OneDayStockInfoDetail]!
    var stockNoList:[StockList]?
    var filteredItems: [OneDayStockInfoDetail] = []
    var refreshControl: UIRefreshControl!
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func addStockNo(_ sender: Any) {
        let alertController = UIAlertController(title: "新增股票代號", message: "請輸入股票代號", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "股票代號"
            textField.keyboardType = .decimalPad
        }
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let stockNo = alertController.textFields?[0].text {
                
                self.stockNoList?.append(StockList(stockNo: stockNo))
                MyStockList.saveToDisk(stockList: self.stockNoList!)
                self.fetchOneDayStockInfo()
                
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        navigationItem.leftBarButtonItem = editButtonItem
        stockNoList = MyStockList.loadFromDisk()
        
        
        fetchOneDayStockInfo()

        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }
   
    
    func fetchOneDayStockInfo() {
        OneDayStockInfo.fetchOneDayStockInfo(stockList: MyStockList.loadFromDisk()){ result in
            switch result {
            case .success(let stockInfo):
                //print("success: \(stockInfo)")
                self.onedayStockInfo = stockInfo.msgArray
                self.filteredItems = self.onedayStockInfo
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                
            case .failure(let error):
                print("failure: \(error)")
            }
        }
    }

    @objc func refreshData(){
        self.refreshControl.endRefreshing()
        self.fetchOneDayStockInfo()
    }

}

extension StockListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return self.onedayStockInfo?.count ?? 0
        return self.filteredItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockPriceInfoCell", for: indexPath) as! StockTableViewCell
        //let stockpriceDetail = onedayStockInfo[indexPath.row]
        let stockpriceDetail = filteredItems[indexPath.row]
        cell.update(with: stockpriceDetail)

        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stockViewController = storyboard?.instantiateViewController(identifier: "stockViewController") as! StockViewController
        
//        stockViewController.stockNo = onedayStockInfo[indexPath.row].c
//        stockViewController.stockPrice = onedayStockInfo[indexPath.row].z
        stockViewController.stockNo = filteredItems[indexPath.row].c
        stockViewController.stockPrice = filteredItems[indexPath.row].z
        navigationController?.pushViewController(stockViewController, animated: true)
    }
    
    // MARK: delete row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let index = indexPath.row
        let itemToDelete = filteredItems[index]
        if editingStyle == .delete {
            //self.stockNoList?.remove(at: index) // edit current stockno list
            //self.onedayStockInfo.remove(at: index) // edit tableview datasource
            self.stockNoList = stockNoList?.filter({
                $0.stockNo != itemToDelete.c
            })
            self.onedayStockInfo = onedayStockInfo.filter({
                $0.c != itemToDelete.c
            })
            self.filteredItems = filteredItems.filter({
                $0.c != itemToDelete.c
            })
            tableView.deleteRows(at: [indexPath], with: .automatic)
            MyStockList.saveToDisk(stockList: self.stockNoList!) // save stockNo list change to disk
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    // called by pressing edit button
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        // toggle editing mode of tableview
        tableView.setEditing(editing, animated: true)
    }
    
    
}

extension StockListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let searchTerm = searchBar.text ?? ""
        search(searchTerm)
        searchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        filteredItems = onedayStockInfo
        tableView.reloadData()
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    func search(_ searchTerm: String) {
        if searchTerm.isEmpty {
            filteredItems = onedayStockInfo
        } else {
            filteredItems = onedayStockInfo.filter({
                $0.c.contains(searchTerm)
            })
        }
        
        tableView.reloadData()
    }
}
