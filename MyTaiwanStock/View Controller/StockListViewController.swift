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
        button.translatesAutoresizingMaskIntoConstraints = false
       
        return button
    }()
    let secondaryButton1 = UIButton(type: .custom)
    let secondaryButton2 = UIButton(type: .custom)
    let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

    
    override func viewDidLoad() {
        super.viewDidLoad()
        logger.debug("list vc viewDidLoad")
        viewModel = StockListViewModel.shared
        
        tableView.delegate = self
        tableView.dataSource = self

        
        tableView.tableFooterView = UIView()
        
        searchBar.delegate = self
        self.navigationController?.delegate = self
        navigationItem.leftBarButtonItem = editButtonItem

        
        // pull refresh
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        bindViewModel()
        // Listening to label tap notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePercentage),
            name: NSNotification.Name("labelTapped"),
            object: nil
        )
        
        // 點空白處隱藏鍵盤
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // 這確保了點擊其他控件（如按鈕）時，不會干擾它們的事件
        view.addGestureRecognizer(tapGesture)
        initView()

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
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 只有初次打開才顯示教學
        if !UserDefaults.standard.bool(forKey: UserDefaults.isFirstTimeAfterSignIn) {
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
       resetFloatingButtonState()
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
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
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


    
    
    @objc func refreshData(){
        self.refreshControl.endRefreshing()
        viewModel.repeatFetch(stockNos: Array(viewModel.stockNameStringSetCombine.value))
    }
    
    @objc private func goToAddStockNoVC() {
        print("tapFloatingButton")
        let buttonsAreHidden = secondaryButton1.alpha == 0
        
        UIView.animate(withDuration: 0.3) {
            self.secondaryButton1.alpha = buttonsAreHidden ? 1 : 0
            self.secondaryButton2.alpha = buttonsAreHidden ? 1 : 0
            self.blurEffectView.alpha = buttonsAreHidden ? 1 : 0
        }

    }
    func navigateToVC<T: UIViewController>(identifier: String, viewControllerType: T.Type) {
        let VC = self.storyboard?.instantiateViewController(withIdentifier: identifier) as! T
        self.navigationController?.pushViewController(VC, animated: true)
    }
    func configureMenu(actionList: [UIAction]?) {
        guard var actionList = actionList else {
            return
        }
        
        actionList.append(
            UIAction(title: "編輯", handler: { action in
                self.navigateToVC(identifier: "addListVC", viewControllerType: AddListViewController.self)
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
    func setupFloatingButtons() {
        view.addSubview(floatingButton)

        NSLayoutConstraint.activate([
            floatingButton.widthAnchor.constraint(equalToConstant: 50),
            floatingButton.heightAnchor.constraint(equalToConstant: 50),
            floatingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            floatingButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
    }
    func setupSecondaryButtons() {
        configureButton(secondaryButton1, title: "新增清單", color: .systemBlue, offsetY: -90, action: #selector(secondaryButton1Tapped))
        configureButton(secondaryButton2, title: "新增股票", color: .systemBlue, offsetY: -150, action: #selector(secondaryButton2Tapped))
    }
    func configureButton(_ button: UIButton, title: String, color: UIColor, offsetY: CGFloat, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = color
        button.layer.cornerRadius = 10 // Adjust for desired corner radius
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.alpha = 0 // Hidden initially
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16) // Set padding
        button.addTarget(self, action: action, for: .touchUpInside)

        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 40), // Adjust for desired height
            button.trailingAnchor.constraint(equalTo: floatingButton.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: floatingButton.bottomAnchor, constant: offsetY),
            //               button.leadingAnchor.constraint(equalTo: floatingButton.leadingAnchor)
        ])
    }
    func setupBlurEffectView() {
          blurEffectView.translatesAutoresizingMaskIntoConstraints = false
          blurEffectView.alpha = 0 // Hidden initially
          view.insertSubview(blurEffectView, belowSubview: floatingButton)
          
          NSLayoutConstraint.activate([
              blurEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              blurEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              blurEffectView.topAnchor.constraint(equalTo: view.topAnchor),
              blurEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
          ])
      }
    func initView() {
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 50 // for skeleton view to calculate height
        navigationItem.titleView?.tintColor = .systemBlue
        setupFloatingButtons()
        setupSecondaryButtons()
        setupBlurEffectView()
    }
    func resetFloatingButtonState() {
           secondaryButton1.alpha = 0
           secondaryButton2.alpha = 0
           blurEffectView.alpha = 0
       }
    @objc func secondaryButton1Tapped() {
        print("Secondary button 1 tapped")
        // Add additional actions for secondary button 1 here
        self.navigateToVC(identifier: "addListVC", viewControllerType: AddListViewController.self)
    
    }
    
    @objc func secondaryButton2Tapped() {
        print("Secondary button 2 tapped")
        // Add additional actions for secondary button 2 here
        let addStockViewController = storyboard?.instantiateViewController(identifier: "addStockVC") as! AddStockNoViewController
        addStockViewController.followingStockNoList = viewModel.stockNameStringSetCombine.value
        addStockViewController.addNewStockToDB = saveNewStockNumberToDB(stockNumber:)
        
        addStockViewController.listName = viewModel.menuTitleCombine
        navigationController?.pushViewController(addStockViewController, animated: false)
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

extension StockListViewController: SkeletonTableViewDataSource, UITableViewDelegate {
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
       return "stockPriceInfoCell"
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return cellDatas.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockPriceInfoCell", for: indexPath) as! StockTableViewCell
        cell.viewController = self

        let cellViewModel = cellDatas[indexPath.row]
        cell.update(with: cellViewModel, isPercentFormat: showPercentage)
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
        UserDefaults.standard.set(viewModel.currentMenuIndexCombine.value, forKey: UserDefaults.menuIndex)
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
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
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
            UserDefaults.standard.set(false, forKey: UserDefaults.isFirstTimeOpenApp)
        }
    }
}
