//
//  ViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//
import WidgetKit
import UIKit
import CoreData

class StockListViewController: UIViewController {
    var userDefault = UserDefaults(suiteName: "group.a2006mike.myTaiwanStock")
    var context: NSManagedObjectContext?
    var followingListObjectFromDB: [List] = []
    var followingListSelectionMenu: [String] = [] {
        didSet {
            print("didset \(followingListSelectionMenu)")
            
            generateMenu()
        }
    }
    var currentMenuIndex: Int = 0 {
        didSet {
            //print("didset currentMenuIndex \(currentMenuIndex)")
            stockNameStringSet.removeAll()
            //self.fetchStockNoFromDB()
            guard let setOfStockNoObjects = followingListObjectFromDB[currentMenuIndex].stockNo else { return }
            let stockNoStringArray:[String] = setOfStockNoObjects.map { ele -> String in
                guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
                //print("\(followingListObjectFromDB[currentMenuIndex].name)  \(stockNo)")
                return stockNo
            }
            stockNameStringSet = Set(stockNoStringArray)
            
            if #available(iOS 15, *) {
            } else {
                generateMenu()
            }
            
        }
        
    }
    

    
    var onedayStockInfo: [OneDayStockInfoDetail] = [] // stock price detail from api
    var stockNameStringSet: Set<String> = [] {
        didSet {
            //print("didset stockNoList \(stockNameStringSet)")
            guard !stockNameStringSet.isEmpty else {
                self.filteredItems.removeAll()
                self.tableView.reloadData()
                return
                
            }
            repeatFetchOneDayStockInfoFromAPI()
        }
    }
    var filteredItems: [OneDayStockInfoDetail] = []
    var refreshControl: UIRefreshControl!
    private var timer: DispatchSourceTimer?
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var popUpButton: UIButton!
    @IBAction func goToAddStockNoVC(_ sender: Any) {

        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = stockNameStringSet
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)
        addStockViewController.list = followingListObjectFromDB[currentMenuIndex]
        navigationController?.pushViewController(addStockViewController, animated: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        tableView.tableFooterView = UIView()
        
        navigationItem.leftBarButtonItem = editButtonItem
        //navigationItem.title = "自選清單"
        setupMenuSelector()
        
        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }
    override func viewWillAppear(_ animated: Bool) {
        let listObjectFromDB = fetchAllListFromDB()
        
        if listObjectFromDB.isEmpty {
            // if no existing following list in db, create a default one
            guard let newList = saveNewListToDB(listName: "預設清單1") else { return }
            self.followingListSelectionMenu.append(newList.name!)
            self.followingListObjectFromDB.append(newList)
            currentMenuIndex = 0
        }
        if !listObjectFromDB.isEmpty {
            self.followingListSelectionMenu = listObjectFromDB.map({ list in
                list.name!
            })
            self.followingListObjectFromDB = listObjectFromDB
            
            currentMenuIndex = 0
        }
        //print("stocklist vc viewWillAppear")
    }
    override func viewWillDisappear(_ animated: Bool) {
        timer?.cancel()
        timer = nil
    }
    
    
    func fetchOneDayStockInfoFromAPI() {
        //guard let stockNoList = fetchedResultsController.fetchedObjects else { return }
        let stockNoListArray = Array(self.stockNameStringSet)
        OneDayStockInfo.fetchOneDayStockInfo(stockList: stockNoListArray ){ result in
            switch result {
            case .success(let stockInfo):
                //print("success: \(stockInfo)")
                self.onedayStockInfo = stockInfo.msgArray
                self.filteredItems = self.onedayStockInfo
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                
                // convert to CommonStockInfo struct type and save to userDefault

                self.saveListToUserDefault()
                
                
                
            case .failure(let error):
                print("failure: \(error)")
            }
        }
    }
    func repeatFetchOneDayStockInfoFromAPI() {
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer!.schedule(deadline: .now(), repeating: DispatchTimeInterval.seconds(60*1))
        timer!.setEventHandler { [weak self] in

            self?.fetchOneDayStockInfoFromAPI()
            
        }
        timer!.resume()
    }
    func saveListToUserDefault() {
        let encoder = JSONEncoder()
        let stockListForWidget = self.onedayStockInfo.map { item in
            return CommonStockInfo(stockNo: item.stockNo, current: item.current, shortName: item.shortName, yesterDayPrice: item.yesterDayPrice)
        }
        do {
            let stockListForWidgetEncode = try encoder.encode(stockListForWidget)
            self.userDefault?.setValue(stockListForWidgetEncode, forKey: "stockList")
            WidgetCenter.shared.reloadAllTimelines()
        } catch let error{
            print(error)
        }
    }
    @objc func refreshData(){
        self.refreshControl.endRefreshing()
        self.fetchOneDayStockInfoFromAPI()
    }
    
    func setupMenuSelector() {
        self.popUpButton.frame.size.width = 200
        //self.menu = ["統一7-ELEVEn獅隊▼","中信兄弟隊"]

    }
    
    
    func generateMenu() {
        if #available(iOS 15, *) {
        } else {
            self.popUpButton.setTitle(followingListSelectionMenu[currentMenuIndex], for: .normal)
        }
        var actions = self.followingListSelectionMenu.enumerated().map { index, str in
            UIAction(title: str, state: index == self.currentMenuIndex ? .on: .off, handler: { action in
                // click the action item
                //print("index \(index), str \(str)")
                self.currentMenuIndex = index
                if #available(iOS 15, *) {
                } else {
                    self.popUpButton.setTitle(str, for: .normal)
                }
            })
        }
        actions.append(
            UIAction(title: "編輯", handler: { action in

                // go to addlistVC page
                let addListVC = self.storyboard?.instantiateViewController(withIdentifier: "addListVC") as! AddListViewController
                self.navigationController?.pushViewController(addListVC, animated: true)
            }))
        popUpButton.menu = UIMenu(children: actions)
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
            
            
            // find the stockNo object to be deleted
            guard let stockNoSet = followingListObjectFromDB[currentMenuIndex].stockNo else { return }
            
            let stockNoObjectArray = stockNoSet.map({ ele -> StockNo in
                let stockNoObject = ele as! StockNo
                return stockNoObject
            })
            let stockNoObjectToDel = stockNoObjectArray[indexPath.row]
            // TODO: when delete stockNumberInDB, also delete related stockHistory 
            deleteStockNumberInDB(stockNoObject: stockNoObjectToDel)
            
            self.onedayStockInfo = onedayStockInfo.filter({
                $0.stockNo != itemToDelete.stockNo
            })
            self.filteredItems = filteredItems.filter({
                $0.stockNo != itemToDelete.stockNo
            })
            tableView.deleteRows(at: [indexPath], with: .automatic)
  
            self.stockNameStringSet = self.stockNameStringSet.filter { stockNo in
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
// MARK: core data CRUD
extension StockListViewController {
    func fetchAllListFromDB() -> [List]{
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        var lists: [List] = []
        do {
            guard let result = try context?.fetch(fetchRequest) else { return [List]() }
            //print("lists \(result)")

            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    func checkIfRemainingStockNoObject(with stockNo: String) -> Bool {
        let fetchStockRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchStockRequest.predicate = predicate
        
        if let stockNoObjects = try? context?.fetch(fetchStockRequest) {
  
            if stockNoObjects.isEmpty {
                // there's no stockNo object with same stockNo
                return false
            }
            
        }
        return true
    }
    func saveNewListToDB(listName: String) -> List? {
        
        let newList = List(context: context!)
        newList.name = listName
        
        do {
            try context?.save()

            return newList
         
        } catch {
            print("error, \(error.localizedDescription)")
            return nil
        }
        
    }
    func saveNewStockNumberToDB(stockNumber: String) {
        //print("saveNewStockNumberToDB...\(stockNumber)")
        guard let context = self.context else { return }

        if self.stockNameStringSet.firstIndex(of: stockNumber) != nil { return }
        let newStockNo = StockNo(context: context)
        newStockNo.stockNo = stockNumber
        newStockNo.ofList = followingListObjectFromDB[currentMenuIndex] // set the relationship between list and stockNo
        //lists[currentMenuIndex].stockNo = NSSet(array: [newStockNo])
        do {
            try context.save()
        } catch {
            print("error, \(error.localizedDescription)")
        }
 
    }
    func deleteStockNumberInDB(stockNoObject: StockNo) {
        context?.delete(stockNoObject)
        
        let result = checkIfRemainingStockNoObject(with: stockNoObject.stockNo!)
        
        if !result {
            deleteHistory(with: stockNoObject.stockNo!)
        }
        // TODO: show the UIAlert
        try? context?.save()

    }
    func deleteHistory(with stockNo: String) {
        // fetch history with stockNo, then delete them
        let fetchHistoryRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchHistoryRequest.predicate = predicate
        
        if let historyObjects = try? context?.fetch(fetchHistoryRequest) {
            //print("historyObjects \(historyObjects)")
            
            for history in historyObjects {
                context?.delete(history)
            }
            try? context?.save()
        }
        
       
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


