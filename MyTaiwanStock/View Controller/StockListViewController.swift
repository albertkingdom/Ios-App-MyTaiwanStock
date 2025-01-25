import Combine
import CoreData
import SkeletonView
import UIKit
//
//  ViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//
import WidgetKit

class StockListViewController: UIViewController, Navigator {
    typealias Destination = UIViewController
    
    let networkService = NetworkServiceImpl()

    var subscription = Set<AnyCancellable>()

    var context: NSManagedObjectContext?
    var viewModel: StockListViewModel!
    var cellDatas: [StockCellViewModel] = []
    var refreshControl: UIRefreshControl!
    var showPercentage = false
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    // button at center of navigation bar
    lazy var navCenterButton: UIButton = {
        guard let rightIcon = UIImage(systemName: "chevron.down") else {
            return UIButton()
        }
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        button.rightIcon(with: rightIcon)
        button.setTitleColor(.label, for: .normal)
        button.widthAnchor.constraint(equalToConstant: 150).isActive = true
        button.translatesAutoresizingMaskIntoConstraints = false
        self.navigationItem.titleView = button
        button.showsMenuAsPrimaryAction = true  //to show menu on tap button

        return button
    }()
    let floatingButton = FloatingButton()
  

    func configure(with viewModel: StockListViewModel) {
        self.viewModel = viewModel
    }
    private func setupFloatingButton(){
        floatingButton.addTarget(self, action: #selector(goToAddStockNoVC), for: .touchUpInside)
    }
    private var floatingButtonManager: FloatingButtonManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.debug("list vc viewDidLoad")

        tableView.delegate = self
        tableView.dataSource = self

        tableView.tableFooterView = UIView()

        searchBar.delegate = self
        self.navigationController?.delegate = self
        navigationItem.leftBarButtonItem = editButtonItem

        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(
            self, action: #selector(refreshData), for: .valueChanged)
        bindViewModel()
        // Listening to label tap notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePercentage),
            name: NSNotification.Name("labelTapped"),
            object: nil
        )

        // 點空白處隱藏鍵盤
        let tapGesture = UITapGestureRecognizer(
            target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // 這確保了點擊其他控件（如按鈕）時，不會干擾它們的事件
        view.addGestureRecognizer(tapGesture)
        initView()
        floatingButtonManager = FloatingButtonManager(parentView: self.view, floatingButton: floatingButton, delegate: self)
        setupFloatingButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        logger.debug("viewwillappear")
        setupSearchBarListener()

        let savedMenuIndex = getSavedListIndex()
        viewModel.setInitialMenuIndex(to: savedMenuIndex)

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        floatingButtonManager.resetFloatingButtonState()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 只有初次打開才顯示教學

        if UserDefaults.standard.bool(
            forKey: UserDefaults.isFirstTimeOpenApp, defaultValue: true)
        {
            presentWalkthrough(for: floatingButton, hintText: "點擊新增")
        }
    }
    @objc func onAppEnterForeground() {
        logger.debug("view enter foreground")
    }
    @objc func onAppEnterBackground() {
        logger.debug("onAppEnterBackground")
        viewModel.cancelTimer()
    }
    override func viewDidLayoutSubviews() {
        //        tableView.showAnimatedSkeleton()

    }
    override func viewWillDisappear(_ animated: Bool) {
        logger.debug("viewWillDisappear")
        viewModel.cancelTimer()
        saveCurrentListIndex()
    }

    func bindViewModel() {
        logger.debug("bindViewModel")
        viewModel.menuActionsCombine
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actionList in
                self?.configureMenu(actionList: actionList)
            }
            .store(in: &subscription)

        viewModel.$menuTitleCombine.sink { [weak self] title in
            DispatchQueue.main.async {
                self?.navCenterButton.setTitle(title, for: .normal)
            }
        }.store(in: &subscription)

        viewModel.filteredStockCellDatasCombine
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cellViewmodels in
                print("cellViewmodels \(cellViewmodels)")
                self?.cellDatas = cellViewmodels
                self?.tableView.reloadData()
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 1,
                    execute: {
                        self?.tableView.hideSkeleton()
                    })
            }
            .store(in: &subscription)

        //        viewModel.currentMenuIndexCombine
        //            .sink(receiveValue: {[weak self] index in
        //                logger.debug("currentMenuIndex \(index)")
        //                self?.currentMenuIndex = index
        //            })
        //            .store(in: &subscription)
        //
        //        Publishers.CombineLatest(viewModel.$shouldShowAlert, viewModel.$isLoading)
        //            .sink { [weak self] isLoading, shouldShowTip in
        //                print("isLoading=\(isLoading), should \(shouldShowTip)")
        //                if !isLoading && shouldShowTip {
        //                    self?.showCustomAlert()
        //
        //                }
        //            }.store(in: &subscription)

    }
    //    func showCustomAlert() {
    //        let alert = UIAlertController(title: "Alert", message: "新增您的第一筆收藏清單", preferredStyle: .alert)
    //
    //        alert.addAction(UIAlertAction(title: "帶我去！", style: .default, handler: { [weak self] _ in
    //            let vc = self?.storyboard?.instantiateViewController(identifier: "addListVC") as! AddListViewController
    //
    //            self?.navigationController?.pushViewController(vc, animated: false)
    //            self?.viewModel.shouldShowAlert = false
    //        }))
    //        self.present(alert, animated: true, completion: nil)
    //    }

    @objc func refreshData() {
        self.refreshControl.endRefreshing()
        viewModel.repeatFetch(
            stockNos: Array(viewModel.stockNameStringSetCombine.value))
    }

    @objc private func goToAddStockNoVC() {
        print("tapFloatingButton")
        let hasMoreThanOneList = viewModel.handleFetchListFromDB()  // 是否有建立清單
        floatingButtonManager.toggleSecondaryButtons(hasMoreThanOneList: hasMoreThanOneList, parentFloatingButton: floatingButton)
    }

    func configureMenu(actionList: [UIAction]?) {
        guard var actionList = actionList else {
            return
        }

        actionList.append(
            UIAction(
                title: "編輯",
                handler: { action in
                    self.navigateToVC(identifier: "addListVC")
                }))
        self.navCenterButton.menu = UIMenu(children: actionList)
    }

    func setupSearchBarListener() {
        let publisher = NotificationCenter.default.publisher(
            for: UISearchTextField.textDidChangeNotification,
            object: searchBar.searchTextField)

        publisher
            .compactMap { notification in
                (notification.object as? UITextField)?.text
            }
            .sink { [weak self] str in
                self?.viewModel.searchText.send(str)
            }
            .store(in: &subscription)
    }
    func setupFloatingButtons() {
        view.addSubview(floatingButton)

        NSLayoutConstraint.activate([
            floatingButton.widthAnchor.constraint(equalToConstant: 50),
            floatingButton.heightAnchor.constraint(equalToConstant: 50),
            floatingButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -20),
            floatingButton.bottomAnchor.constraint(
                equalTo: view.bottomAnchor, constant: -100),
        ])
    }
    
    
    
    func initView() {
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 50  // for skeleton view to calculate height
        navigationItem.titleView?.tintColor = .systemBlue
        setupFloatingButtons()

    }


    deinit {
        logger.debug("stock list vc deinit")
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
}

extension StockListViewController: SkeletonTableViewDataSource,
    UITableViewDelegate
{
    func collectionSkeletonView(
        _ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath
    ) -> ReusableCellIdentifier {
        return "stockPriceInfoCell"
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
        -> Int
    {

        return cellDatas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        let cell =
            tableView.dequeueReusableCell(
                withIdentifier: "stockPriceInfoCell", for: indexPath)
            as! StockTableViewCell
        cell.viewController = self

        let cellViewModel = cellDatas[indexPath.row]
        cell.update(with: cellViewModel, isPercentFormat: showPercentage)
        cell.selectionStyle = .none

        return cell
    }
    func tableView(
        _ tableView: UITableView, didSelectRowAt indexPath: IndexPath
    ) {

        let cellViewModel = cellDatas[indexPath.row]
        let stockViewController = DependencyContainer.shared
            .configureStockDetailViewController(
                stockNo: cellViewModel.stockNo,
                currentStockPrice: cellViewModel.stockPrice
            )

        //        stockViewController.stockNo = cellViewModel.stockNo
        stockViewController.stockPrice = cellViewModel.stockPrice
        stockViewController.stockName = cellViewModel.stockShortName
        stockViewController.stockPriceDiff = cellViewModel.stockPriceDiff
        stockViewController.timeString = cellViewModel.time
        //        stockViewController.context = self.context // TODO:

        navigationController?.pushViewController(
            stockViewController, animated: true)

    }
    func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return 100
    }
    // MARK: delete row
    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {

        if editingStyle == .delete {

            deleteStockNumber(at: indexPath.row)
            cellDatas.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)

        }
    }

    func tableView(
        _ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        return .delete
    }

    // called by pressing edit button
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        // toggle editing mode of tableview
        tableView.setEditing(editing, animated: true)
    }

    @objc func togglePercentage() {
        showPercentage.toggle()
        tableView.reloadData()
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
        UserDefaults.standard.set(
            viewModel.currentMenuIndexCombine.value,
            forKey: UserDefaults.menuIndex)
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

extension StockListViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController, animated: Bool
    ) {
        if viewController == self {
            logger.debug("從其他vc返回到stock list vc")
            viewModel.handleFetchListFromDB()
        }
    }
}

extension StockListViewController {
    func presentWalkthrough(for view: UIView, hintText: String) {
        let walkthroughVC = WalkthroughViewController()
        walkthroughVC.modalPresentationStyle = .overFullScreen
        walkthroughVC.modalTransitionStyle = .crossDissolve
        walkthroughVC.targetView = view
        walkthroughVC.hintText = hintText
        self.present(walkthroughVC, animated: true) {
            // 顯示教學後，設定"初次打開"為false
            UserDefaults.standard.set(
                false, forKey: UserDefaults.isFirstTimeOpenApp)
        }
    }
}


extension StockListViewController: FloatingButtonManagerDelegate {
    func didTapSecondaryButton1() {
        navigateToVC(identifier: "addListVC")
    }
    
    func didTapSecondaryButton2() {
        let addStockViewController =
            storyboard?.instantiateViewController(identifier: "addStockVC")
            as! AddStockNoViewController
        addStockViewController.followingStockNoList =
            viewModel.stockNameStringSetCombine.value
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(
            stockNumber:)

        addStockViewController.listName = viewModel.menuTitleCombine
        navigationController?.pushViewController(
            addStockViewController, animated: false)
    }
    
    
}
