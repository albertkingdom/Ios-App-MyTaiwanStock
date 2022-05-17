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
    let viewModel: StockListViewModel = StockListViewModel()
    
    var refreshControl: UIRefreshControl!
    private var timer: DispatchSourceTimer?
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var popUpButton: UIButton!
    @IBAction func goToAddStockNoVC(_ sender: Any) {

        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = viewModel.stockNameStringSet.value ?? []
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)

        addStockViewController.listName = viewModel.menuTitle.value
        navigationController?.pushViewController(addStockViewController, animated: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.context = self.context
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        tableView.tableFooterView = UIView()
        
        navigationItem.leftBarButtonItem = editButtonItem

        setupMenuButton()
        
        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }
    override func viewWillAppear(_ animated: Bool) {

        //print("stocklist vc viewWillAppear")
        viewModel.handleFetchListFromDB()
        
        bindViewModel()
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        timer?.cancel()
        timer = nil
    }
    
    func bindViewModel() {
        viewModel.stockNameStringSet.bind { [weak self] set in
            //print("set \(set)")
            if let count = set?.count, count > 0 {
                self?.timer?.cancel()
                self?.repeatFetchOneDayStockInfoFromAPI()
            } else {
                self?.viewModel.stockCellDatas.value = []
            }
            
        }
        
        viewModel.menuActions.bind { [weak self] actionList in
            self?.configureMenu(actionList: actionList)
        }
        viewModel.menuTitle.bind { [weak self] title in
            self?.popUpButton.setTitle(title, for: .normal)
        }
        viewModel.stockCellDatas.bind { [weak self] _ in
            self?.tableView.reloadData()
            self?.saveListToUserDefault()
        }
    }
    
    func repeatFetchOneDayStockInfoFromAPI() {
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer!.schedule(deadline: .now(), repeating: DispatchTimeInterval.seconds(60*1))
        timer!.setEventHandler { [weak self] in

            self?.viewModel.fetchOneDayStockInfoFromAPI()
            
        }
        timer!.resume()
    }
    
    func saveListToUserDefault() {
        let encoder = JSONEncoder()
        let stockListForWidget = viewModel.onedayStockInfo.map { item in
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
        timer?.cancel()
        self.repeatFetchOneDayStockInfoFromAPI()
//        viewModel.fetchOneDayStockInfoFromAPI()
    }
    
    func setupMenuButton() {

        self.popUpButton.frame = CGRect(x: 0, y: 0, width: 120, height: 40)
        self.popUpButton.backgroundColor = UIColor.lightGray
        self.popUpButton.layer.cornerRadius = self.popUpButton.frame.height / 2

    }
    
    func configureMenu(actionList: [UIAction]?) {
        guard var actionList = actionList else {
            return
        }
        
        actionList.append(
            UIAction(title: "編輯", handler: { action in
                
                // go to addlistVC page
                let addListVC = self.storyboard?.instantiateViewController(withIdentifier: "addListVC") as! AddListViewController
                self.navigationController?.pushViewController(addListVC, animated: true)
            }))
        
        self.popUpButton.menu = UIMenu(children: actionList)
    }


       
    
  
    
}

extension StockListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return viewModel.stockCellDatas.value?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockPriceInfoCell", for: indexPath) as! StockTableViewCell

        guard let cellViewModel = viewModel.stockCellDatas.value?[indexPath.row] else { return UITableViewCell() }
        cell.update(with: cellViewModel)
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stockViewController = storyboard?.instantiateViewController(identifier: "stockViewController") as! StockViewController
        guard let cellViewModel = viewModel.stockCellDatas.value?[indexPath.row] else { return }
        
        stockViewController.stockNo = cellViewModel.stockNo
        stockViewController.stockPrice = cellViewModel.stockPrice
        stockViewController.stockName = cellViewModel.stockShortName
        stockViewController.context = self.context // TODO:


        navigationController?.pushViewController(stockViewController, animated: true)

    }
    
    // MARK: delete row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        
        if editingStyle == .delete {
            
            deleteStockNumber(at: indexPath.row)
            
            tableView.deleteRows(at: [indexPath], with: .automatic)
  
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
    
    
    
    func saveNewStockNumberToDB(stockNumber: String) {
        viewModel.saveNewStockNumberToDB(stockNumber: stockNumber)
    }
    func deleteStockNumber(at index: Int) {
        viewModel.deleteStockNumber(at: index)
    }
    
    
}
// MARK: search bar
extension StockListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let searchTerm = searchBar.text ?? ""
        viewModel.search(searchTerm)
        searchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
      
        viewModel.stockCellDatas.value = viewModel.onedayStockInfo.map({ item in
            StockCellViewModel(stock: item)
        })
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
}


