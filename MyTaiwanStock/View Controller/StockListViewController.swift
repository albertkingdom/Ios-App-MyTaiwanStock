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
    var viewModel: StockListViewModel!
    var cellDatas: [StockCellViewModel] = []
    var refreshControl: UIRefreshControl!

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    @IBAction func goToAddStockNoVC(_ sender: Any) {

        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = viewModel.stockNameStringSetCombine.value
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)

        addStockViewController.listName = viewModel.menuTitleCombine
        navigationController?.pushViewController(addStockViewController, animated: true)
    }
    // button at center of navigation bar
    lazy var navCenterButton: UIButton = {
        guard let rightIcon = UIImage(systemName: "chevron.down") else { return UIButton() }
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        button.rightIcon(with: rightIcon)
        button.setTitleColor(.label, for: .normal)
        button.widthAnchor.constraint(equalToConstant: 150).isActive = true
        button.translatesAutoresizingMaskIntoConstraints = false
        self.navigationItem.titleView = button
        button.showsMenuAsPrimaryAction = true //to show menu on tap button
        
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("list vc viewDidLoad")
        viewModel = StockListViewModel()
        viewModel.context = self.context
        viewModel.onlineDBService = OnlineDBService(context: context)
        viewModel.localDB = LocalDBService(context: context)
        
        tableView.delegate = self
        tableView.dataSource = self

        
        tableView.tableFooterView = UIView()
        
        searchBar.delegate = self
        
        navigationItem.leftBarButtonItem = editButtonItem

        //setupMenuButton()
        
        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        initView()
        bindViewModel()
    }
    override func viewWillAppear(_ animated: Bool) {
        
        setupSearchBarListener()
        
        // re trigger timer
        viewModel.repeatFetch(stockNos: viewModel.stockNoStringCombine.value)
        
        let isFirstTimeAfterSignIn = UserDefaults.standard.bool(forKey: UserDefaults.isFirstTimeAfterSignIn)
       

        if isFirstTimeAfterSignIn {
            // after downloading online data to local database, retrieve all local database at once
            showAlert(title: "下載雲端資料", message: "您剛才登入，將下載雲端資料，是否同意？") { [weak self] in
                self?.viewModel.getOnlineDBDataAndInsertLocal(completion: self?.viewModel.handleFetchListFromDB)
            } negativeAction: { [weak self] in
                self?.viewModel.handleFetchListFromDB()
            }
            UserDefaults.standard.set(false, forKey: UserDefaults.isFirstTimeAfterSignIn)
        } else {
            viewModel.handleFetchListFromDB()
        }
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        print("list VC viewWillDisappear, cancel timer")
        viewModel.cancelTimer()
        
    }
    
    func bindViewModel() {

        viewModel.menuActionsCombine
            .sink { [weak self] actionList in
            self?.configureMenu(actionList: actionList)
        }
        .store(in: &subscription)
        

        viewModel.$menuTitleCombine.sink { [weak self] title in
            self?.navCenterButton.setTitle(title, for: .normal)
        }.store(in: &subscription)
        
        viewModel.$filteredStockCellDatasCombine
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cellViewmodels in
                print("cellViewmodels \(cellViewmodels)")
                self?.cellDatas = cellViewmodels
                self?.tableView.reloadData()
            }
            .store(in: &subscription)
        
       
        viewModel.dataForWidget
            .sink { [weak self] data in
                
                self?.saveListToUserDefault(data: data)
            }
            .store(in: &subscription)
        
        viewModel.stockNoStringCombine
            .sink { [weak self] stockNoStrings in
                //print("stockNoStrings \(stockNoStrings)")
                self?.userDefault?.setValue(stockNoStrings, forKey: "stockNos")
                WidgetCenter.shared.reloadAllTimelines()
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
        
        self.navCenterButton.menu = UIMenu(children: actionList)
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
    
    func initView() {
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        
        navigationItem.titleView?.tintColor = .systemBlue
    }
    
}

extension StockListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return cellDatas.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockPriceInfoCell", for: indexPath) as! StockTableViewCell


        let cellViewModel = cellDatas[indexPath.row]
        cell.update(with: cellViewModel)
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stockViewController = storyboard?.instantiateViewController(identifier: "stockViewController") as! StockViewController

        let cellViewModel = cellDatas[indexPath.row]
        
        stockViewController.stockNo = cellViewModel.stockNo
        stockViewController.stockPrice = cellViewModel.stockPrice
        stockViewController.stockName = cellViewModel.stockShortName
        stockViewController.context = self.context // TODO:


        navigationController?.pushViewController(stockViewController, animated: true)

    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    // MARK: delete row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        
        if editingStyle == .delete {
            
            deleteStockNumber(at: indexPath.row)
            cellDatas.remove(at: indexPath.row)
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

extension StockListViewController {
    
    
    
    func saveNewStockNumberToDB(stockNumber: String) {
        viewModel.saveNewStockNumberToDB(stockNumber: stockNumber)
        viewModel.uploadNewStockNoToOnlineDB(stockNumber: stockNumber)
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



