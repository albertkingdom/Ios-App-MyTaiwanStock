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
import SkeletonView

class StockListViewController: UIViewController {
    var subscription = Set<AnyCancellable>()
    
    var userDefault = UserDefaults(suiteName: "group.a2006mike.myTaiwanStock")
    var context: NSManagedObjectContext?
    var viewModel: StockListViewModel!
    var cellDatas: [StockCellViewModel] = []
    var refreshControl: UIRefreshControl!

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

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
    let floatingButton: UIButton = {
       let button = UIButton()
        button.setImage(UIImage(systemName: "plus",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)),
                        for: .normal)
        button.backgroundColor = .black
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.label.cgColor
        button.layer.shadowOpacity = 0.5
        button.layer.shadowOffset = CGSize(width: 5, height: 5)
        button.layer.shadowRadius = 10
        button.setTitle(nil, for: .normal)
        button.addTarget(self, action: #selector(goToAddStockNoVC), for: .touchUpInside)
        return button
    }()
    var currentMenuIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("list vc viewDidLoad")
        viewModel = StockListViewModel()
        
        tableView.delegate = self
        tableView.dataSource = self

        
        tableView.tableFooterView = UIView()
        
        searchBar.delegate = self
        
        navigationItem.leftBarButtonItem = editButtonItem

        
        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        initView()
        bindViewModel()
    }
    override func viewWillAppear(_ animated: Bool) {
        
        setupSearchBarListener()
        
        
        let isFirstTimeAfterSignIn = UserDefaults.standard.bool(forKey: UserDefaults.isFirstTimeAfterSignIn)
        let savedMenuIndex = getSavedListIndex()
        viewModel.setInitialMenuIndex(to: savedMenuIndex)

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
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never
    }
    override func viewDidLayoutSubviews() {
        tableView.showAnimatedSkeleton()
        view.addSubview(floatingButton)
        floatingButton.frame = CGRect(x: view.frame.width - 80,
                                      y: view.frame.height - 80 - view.safeAreaInsets.bottom,
                                      width: 50, height: 50)
    }
    override func viewWillDisappear(_ animated: Bool) {
        viewModel.cancelTimer()
        saveCurrentListIndex()
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
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    self?.tableView.hideSkeleton()
                })
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
        
        viewModel.currentMenuIndexCombine
            .sink(receiveValue: {[weak self] index in
                self?.currentMenuIndex = index
            })
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
    
    @objc private func goToAddStockNoVC() {
        print("tapFloatingButton")
        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = viewModel.stockNameStringSetCombine.value
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)

        addStockViewController.listName = viewModel.menuTitleCombine
        navigationController?.pushViewController(addStockViewController, animated: true)
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
        tableView.estimatedRowHeight = 50 // for skeleton view to calculate height
        navigationItem.titleView?.tintColor = .systemBlue
    }
    
}

extension StockListViewController: SkeletonTableViewDataSource, UITableViewDelegate {
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
       return "stockPriceInfoCell"
    }
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
        stockViewController.stockPriceDiff = cellViewModel.stockPriceDiff
        stockViewController.timeString = cellViewModel.time
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
        viewModel.saveNewStockNo(stockNumber: stockNumber)
    }
    func deleteStockNumber(at index: Int) {
        viewModel.deleteStockNumber(at: index)
    }
    
    func saveCurrentListIndex() {
        UserDefaults.standard.set(currentMenuIndex, forKey: UserDefaults.menuIndex)
    }
    func getSavedListIndex() -> Int {
        return UserDefaults.standard.integer(forKey: UserDefaults.menuIndex)
    }
    
}

extension StockListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.endEditing(true)
    }
    
}



