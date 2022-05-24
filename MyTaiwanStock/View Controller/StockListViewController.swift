//
//  ViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//
import WidgetKit
import UIKit
import CoreData
import Combine

class StockListViewController: UIViewController {
    var subscription = Set<AnyCancellable>()
    
    var userDefault = UserDefaults(suiteName: "group.a2006mike.myTaiwanStock")
    var context: NSManagedObjectContext?
    let viewModel: StockListViewModel = StockListViewModel()
    
    var refreshControl: UIRefreshControl!

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var popUpButton: UIButton!
    @IBAction func goToAddStockNoVC(_ sender: Any) {

        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = viewModel.stockNameStringSetCombine.value
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)

        addStockViewController.listName = viewModel.menuTitleCombine
        navigationController?.pushViewController(addStockViewController, animated: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.context = self.context
        tableView.delegate = self
        tableView.dataSource = self

        
        tableView.tableFooterView = UIView()
        
        searchBar.delegate = self
        
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
        
        setupSearchBarListener()
    }
    override func viewWillDisappear(_ animated: Bool) {

        viewModel.cancelTimer()
        
    }
    
    func bindViewModel() {

        viewModel.menuActionsCombine
            .sink { [weak self] actionList in
            self?.configureMenu(actionList: actionList)
        }
        .store(in: &subscription)
        

        viewModel.$menuTitleCombine.sink { [weak self] title in
            self?.popUpButton.setTitle(title, for: .normal)
        }.store(in: &subscription)
        
        viewModel.filteredStockCellDatasCombine
            .receive(on: DispatchQueue.main)
            .sink { [weak self] viewmodels in
                print("viewmodels \(viewmodels)")
                self?.tableView.reloadData()
            }
            .store(in: &subscription)
        
       
        viewModel.dataForWidget
            .sink { [weak self] data in
                
                self?.saveListToUserDefault(data: data)
            }
            .store(in: &subscription)
    }
    

    func saveListToUserDefault(data: Data) {

        self.userDefault?.setValue(data, forKey: "stockList")
        WidgetCenter.shared.reloadAllTimelines()
    }
    @objc func refreshData(){
        self.refreshControl.endRefreshing()
    
        viewModel.repeatFetch(stockNos: viewModel.stockNoStringCombine.value)


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

extension StockListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {


        return viewModel.filteredStockCellDatasCombine.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockPriceInfoCell", for: indexPath) as! StockTableViewCell


        let cellViewModel = viewModel.filteredStockCellDatasCombine.value[indexPath.row]
        cell.update(with: cellViewModel)
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stockViewController = storyboard?.instantiateViewController(identifier: "stockViewController") as! StockViewController

        let cellViewModel = viewModel.filteredStockCellDatasCombine.value[indexPath.row]
        
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

extension StockListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.endEditing(true)
    }
    
}



