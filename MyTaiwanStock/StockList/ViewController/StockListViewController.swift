//
//  ViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import Combine
import CoreData
import SkeletonView
import UIKit
import ActivityKit

class StockListViewController: UIViewController, Navigator {

    enum Section {
        case main
    }
    struct Item: Hashable {
        let viewModel: StockCellViewModel
    }

    typealias Destination = UIViewController

    var subscription = Set<AnyCancellable>()

    private var viewModel: StockListViewModel!

    var refreshControl: UIRefreshControl!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    var dataSource: UITableViewDiffableDataSource<Section, Item>?
    private func makeDataSource() {
        let dataSource = UITableViewDiffableDataSource<Section, Item>(
            tableView: tableView,
            cellProvider: { tableView, indexPath, item in
                guard
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: "stockPriceInfoCell", for: indexPath)
                        as? StockTableViewCell
                else {
                    fatalError("Cannot create new cell")
                }
                cell.update(
                    with: item.viewModel
                )
                return cell
            })
        self.dataSource = dataSource
    }
    // button at center of navigation bar
    private lazy var navCenterButton: UIButton = {
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
    private let floatingButton = FloatingButton()

    func configure(with viewModel: StockListViewModel) {
        self.viewModel = viewModel
    }
    func applySnapshot(
        data: [StockCellViewModel], animatingDifferences: Bool = true
    ) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        let items = data.map { Item(viewModel: $0) }
        snapshot.appendItems(items, toSection: .main)
        makeDataSource()
        dataSource?.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    private var floatingButtonManager: FloatingButtonManager!
    var didRefresh = PassthroughSubject<Void, Never>()
    var getData = PassthroughSubject<Void, Never>()
    private var output: StockListViewModel.Output?
    override func viewDidLoad() {
        super.viewDidLoad()
        logger.debug("list vc viewDidLoad")

        edgesForExtendedLayout.insert(.bottom)
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        searchBar.delegate = self
        self.navigationController?.delegate = self
        if viewModel != nil {
            setupWithViewModel()
        }
        // Listening to label tap notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePercentage),
            name: NSNotification.Name("labelTapped"),
            object: nil
        )

        addDismissKeyBoardGesture()
        initView()

    }

    override func viewWillAppear(_ animated: Bool) {
        logger.debug("viewwillappear")

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never

        floatingButtonManager.resetFloatingButtonState()
        getData.send()

    }
    private func setupNotifications() {
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
    private var togglePriceDiffInPercentage = PassthroughSubject<Void, Never>()
    override func viewWillDisappear(_ animated: Bool) {
        logger.debug("viewWillDisappear")
        viewModel.cancelTimer()
        saveCurrentListIndex()
    }

    private func bindViewModel() {
        logger.debug("bindViewModel")
        let input = StockListViewModel.Input(
            didRefresh: didRefresh,
            viewDidLoad: getData,
            togglePriceDiffFormat: togglePriceDiffInPercentage
        )
        let output = viewModel.transform(input: input)
        self.output = output
        viewModel.menuActionsCombine
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actionList in
                self?.configureMenu(actionList: actionList)
            }
            .store(in: &subscription)

        output.menuTitle.sink { [weak self] title in
            DispatchQueue.main.async {
                self?.navCenterButton.setTitle(title, for: .normal)
            }
        }.store(in: &subscription)

        output.stocks
            .receive(on: DispatchQueue.main)
            .print("stocks received)")
            .sink { [weak self] cellViewmodels in
                self?.applySnapshot(
                    data: cellViewmodels, animatingDifferences: true)
            }
            .store(in: &subscription)
        output.isLoading
            .print("isLoading received")
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if !isLoading {
                    self?.refreshControl.endRefreshing()
                    self?.tableView.contentOffset = CGPoint.zero
                }
            }
            .store(in: &subscription)
        

    }
    // 所有需要viewModel的設置
    private func setupWithViewModel() {
        guard let viewModel = viewModel else { return }
        //        viewModel.handleFetchListFromDB()
        floatingButton.addTarget(
            self, action: #selector(goToAddStockNoVC), for: .touchUpInside)
        // Bind view model
        bindViewModel()

        setupSearchBarListener()

        // Setup initial menu index
        let savedMenuIndex = viewModel.getSavedListIndex()
        viewModel.setInitialMenuIndex(to: savedMenuIndex)

        // Setup notifications
        setupNotifications()

        setupPullRefresh()
    }

    @objc func refreshData() {
        didRefresh.send()
    }

    @objc private func goToAddStockNoVC() {
        let hasMoreThanOneList = self.viewModel.listNames.count >= 1  // 是否有建立清單
        floatingButtonManager.toggleSecondaryButtons(
            hasMoreThanOneList: hasMoreThanOneList,
            parentFloatingButton: floatingButton
        )
    }

    private func configureMenu(actionList: [UIAction]?) {
        guard var actionList = actionList else {
            return
        }
        self.navCenterButton.menu = UIMenu(children: actionList)
    }

    func setupSearchBarListener() {
        let publisher = NotificationCenter.default.publisher(
            for: UISearchTextField.textDidChangeNotification,
            object: searchBar.searchTextField)

        publisher
            .compactMap { notification in
                (notification.object as? UITextField)?.text?.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] str in
                self?.viewModel.searchText.send(str)
            }
            .store(in: &subscription)
    }
    private func setupFloatingButtonUI() {
        view.addSubview(floatingButton)

        NSLayoutConstraint.activate([
            floatingButton.widthAnchor.constraint(equalToConstant: 50),
            floatingButton.heightAnchor.constraint(equalToConstant: 50),
            floatingButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -20),
            floatingButton.bottomAnchor.constraint(
                equalTo: view.bottomAnchor, constant: -100),
        ])

        floatingButtonManager = FloatingButtonManager(
            parentView: self.view,
            floatingButton: floatingButton,
            delegate: self
        )
    }

    func initView() {
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 50  // for skeleton view to calculate height
        navigationItem.titleView?.tintColor = .systemBlue
        setupFloatingButtonUI()
        navigationItem.leftBarButtonItem = editButtonItem

    }
    func setupPullRefresh() {
        guard let viewModel = viewModel else { return }
        refreshControl = UIRefreshControl()
        tableView.refreshControl = refreshControl
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
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

extension StockListViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView, didSelectRowAt indexPath: IndexPath
    ) {
        guard let item = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }
        let cellViewModel = item.viewModel

        viewModel.navigateToStockDetail(
            stockNo: cellViewModel.stockNo,
            currentStockPrice: cellViewModel.stockPrice,
            stockName: cellViewModel.stockShortName,
            stockPriceDiff: cellViewModel.stockPriceDiff,
            timeString: cellViewModel.time
        )

    }
    func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return 100
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let item = dataSource?.itemIdentifier(for: indexPath) else {
            return nil
        }
        let cellViewModel = item.viewModel

        guard #available(iOS 16.1, *) else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let action = UIAction(
                title: "開啟即時報價",
                image: UIImage(systemName: "chart.line.uptrend.xyaxis")
            ) { [weak self] _ in
                self?.startLiveActivity(from: cellViewModel)
            }
            return UIMenu(children: [action])
        }
    }

    @available(iOS 16.1, *)
    private func startLiveActivity(from cellViewModel: StockCellViewModel) {
        let stockPrice = cellViewModel.stockPrice == "-" ? "0.00" : cellViewModel.stockPrice
        let diffStr = cellViewModel.stockPriceDiff == "-" ? "0.00" : cellViewModel.stockPriceDiff
        let percentStr = cellViewModel.stockPriceDiffPercent == "-" ? "0.000%" : cellViewModel.stockPriceDiffPercent

        let priceChange: String
        if let diffFloat = Float(diffStr) {
            priceChange = diffFloat >= 0 ? String(format: "+%.2f", diffFloat) : String(format: "%.2f", diffFloat)
        } else {
            priceChange = "0.00"
        }

        let priceChangePercent: String
        if let pctFloat = Float(diffStr) {
            priceChangePercent = pctFloat >= 0 ? "+\(percentStr)" : percentStr
        } else {
            priceChangePercent = percentStr
        }

        let yesterDayPrice: String
        if let currentFloat = Float(stockPrice), let diffFloat = Float(diffStr) {
            yesterDayPrice = String(format: "%.2f", currentFloat - diffFloat)
        } else {
            yesterDayPrice = "0.00"
        }

        _ = ActivityManager.shared.start(
            stockNo: cellViewModel.stockNo,
            stockName: cellViewModel.stockShortName,
            currentPrice: stockPrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
            yesterDayPrice: yesterDayPrice,
            time: cellViewModel.time)
    }

    // MARK: swipe to delete row
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(
            style: .destructive, title: "Delete"
        ) { (action, view, completion) in
            guard let dataSource = self.dataSource, let item = dataSource.itemIdentifier(for: indexPath)
            else { return }
            self.viewModel.deleteStockNumber(stockNo: item.viewModel.stockNo)
            var snapshot = dataSource.snapshot()
            snapshot.deleteItems([item])
            dataSource.apply(snapshot, animatingDifferences: true)
            completion(false)
        }
        let confiiguration = UISwipeActionsConfiguration(actions: [deleteAction]
        )
        return confiiguration
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
        togglePriceDiffInPercentage.send()
        //tableView.reloadData()
    }
}

extension StockListViewController {

    func saveCurrentListIndex() {
        viewModel.saveCurrentListIndex()
    }
    func getSavedListIndex() -> Int {
        return viewModel.getSavedListIndex()
    }

}

extension StockListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.endEditing(true)
    }
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }

}

extension StockListViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController, animated: Bool
    ) {
        if viewController == self {
            logger.debug("從其他vc返回到stock list vc")
            //            viewModel.handleFetchListFromDB()
            //            if viewModel != nil {
            //                setupWithViewModel()
            //            }
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
        guard let viewModel = viewModel else {
            logger.debug("ViewModel is nil in didTapSecondaryButton1")
            return
        }
        viewModel.navigateToAddList()
    }

    func didTapSecondaryButton2() {
        guard let viewModel = viewModel else {
            logger.debug("ViewModel is nil in didTapSecondaryButton1")
            return
        }
        viewModel.navigateToAddStock()
    }

}
