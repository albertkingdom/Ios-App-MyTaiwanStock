//
//  ViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import UIKit
import CoreData

class StockListViewController: UIViewController {
    let userDefault = UserDefaults.standard
    var context: NSManagedObjectContext?
    
    lazy var fetchedResultsController: NSFetchedResultsController<StockNo> = {
        let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context!, sectionNameKeyPath: nil, cacheName: nil)
        frc.delegate = self
        return frc
    }()
    
    var onedayStockInfo: [OneDayStockInfoDetail] = []
    var stockNoList: Set<String> = []
    var filteredItems: [OneDayStockInfoDetail] = []
    var refreshControl: UIRefreshControl!
    private var timer: DispatchSourceTimer?
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var tableView: UITableView!
    @IBAction func addStockNo(_ sender: Any) {

        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = stockNoList
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)
        navigationController?.pushViewController(addStockViewController, animated: true)
    }
    func saveNewStockNumberToDB(stockNumber: String) {
        print("saveNewStockNumberToDB...\(stockNumber)")
        guard let context = self.context else { return }

        // core data
        if self.stockNoList.firstIndex(of: stockNumber) != nil { return }
        let newStockNo = StockNo(context: context)
        newStockNo.stockNo = stockNumber

        do {
            try context.save()
            self.stockNoList.insert(stockNumber) //update set in vc
            print("add item to stockNoList, \(self.stockNoList)")
            //self.fetchOneDayStockInfo()
        } catch {
            print("error, \(error.localizedDescription)")
        }

        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        tableView.tableFooterView = UIView()
        
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.title = "自選清單"

        
        //core data
        do {
            try fetchedResultsController.performFetch()
            fetchedResultsController.fetchedObjects?.forEach({
                stockNoList.insert($0.stockNo!)
            })
            print("stockNoList, \(stockNoList)")
        } catch {
            fatalError("Core Data fetch error")
        }
        if let _ = fetchedResultsController.fetchedObjects {
//            fetchOneDayStockInfo()
            repeatFetchOneDayStockInfo()
        }

        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }
   
    
    func fetchOneDayStockInfo() {
        guard let stockNoList = fetchedResultsController.fetchedObjects else { return }
        
        OneDayStockInfo.fetchOneDayStockInfo(stockList: stockNoList ){ result in
            switch result {
            case .success(let stockInfo):
                //print("success: \(stockInfo)")
                self.onedayStockInfo = stockInfo.msgArray
                self.filteredItems = self.onedayStockInfo
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                //self.userDefault.set(self.onedayStockInfo, forKey: "stockPrice")
                
            case .failure(let error):
                print("failure: \(error)")
            }
        }
    }
    func repeatFetchOneDayStockInfo() {
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer!.schedule(deadline: .now(), repeating: DispatchTimeInterval.seconds(60*1))
        timer!.setEventHandler { [weak self] in

            self?.fetchOneDayStockInfo()
            
        }
        timer!.resume()
    }
    @objc func refreshData(){
        self.refreshControl.endRefreshing()
        self.fetchOneDayStockInfo()
    }
    override func viewWillDisappear(_ animated: Bool) {
        timer?.cancel()
        timer = nil
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
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stockViewController = storyboard?.instantiateViewController(identifier: "stockViewController") as! StockViewController

        stockViewController.stockNo = filteredItems[indexPath.row].stockNo
        stockViewController.stockPrice = filteredItems[indexPath.row].current
        stockViewController.stockName = filteredItems[indexPath.row].shortName
        stockViewController.context = self.context
        

        navigationController?.pushViewController(stockViewController, animated: true)

    }
    
    // MARK: delete row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let index = indexPath.row
        let itemToDelete = filteredItems[index]
        if editingStyle == .delete {

            guard let objectToDel = fetchedResultsController.fetchedObjects?.filter({
                $0.stockNo == itemToDelete.stockNo
            })[0] else { return }
            context?.delete(objectToDel)
            try? context?.save()
            
            self.onedayStockInfo = onedayStockInfo.filter({
                $0.stockNo != itemToDelete.stockNo
            })
            self.filteredItems = filteredItems.filter({
                $0.stockNo != itemToDelete.stockNo
            })
            tableView.deleteRows(at: [indexPath], with: .automatic)
  
            self.stockNoList = self.stockNoList.filter { stockNo in
                itemToDelete.stockNo != stockNo
            } // edit current stockno list
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
                $0.stockNo.contains(searchTerm)
            })
        }
        
        tableView.reloadData()
    }
}

extension StockListViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        fetchOneDayStockInfo()
        
    }
}

extension StockListViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 5
    }
    
    
}
