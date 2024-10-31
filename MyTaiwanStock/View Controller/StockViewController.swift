//
//  StockViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/4.
//
import Combine
import CoreData
import UIKit
import Charts
import FirebaseFirestore


class StockViewController: UIViewController {
    var subscription = Set<AnyCancellable>()
    var viewModel: StockDetailViewModel!
    
    var chartService: ChartService!
//    var context: NSManagedObjectContext?
    
    var priceContainerView = UIView()
    var stockPriceLabel = UILabel()
    var arrowImageView = UIImageView()
    var priceDiffLabel = UILabel()
    var timeLabel = UILabel()
    
    var combinedChartView = CombinedChartView()
    private var lastContentOffset: Double = 0
    var stockInfoForCandleStickChart: [[String]]! {
        didSet {
            if let stockPriceDiffString = stockInfoForCandleStickChart.last?[7],
               let stockPriceDiffFloat = Float(stockPriceDiffString) {
                
                priceDiffLabel.text = "\(abs(stockPriceDiffFloat))"
                arrowImageView.tintColor = stockPriceDiffFloat>=0 ? .systemRed : .systemGreen
                priceContainerView.backgroundColor = stockPriceDiffFloat>=0 ? .systemPink.withAlphaComponent(0.5):.systemGreen.withAlphaComponent(0.5)
                stockPriceLabel.textColor = stockPriceDiffFloat>=0 ? .systemRed : .systemGreen
                priceDiffLabel.textColor = stockPriceDiffFloat>=0 ? .systemRed : .systemGreen
                arrowImageView.image = stockPriceDiffFloat>=0 ? UIImage(systemName: "arrowtriangle.up.fill") : UIImage(systemName: "arrowtriangle.down.fill")
            }
        }
    }
    var stockName: String!
    var stockPrice: String!
    var stockPriceDiff: String!
    var timeString: String!
    private let database = Firestore.firestore()
    
    
    var plotDateLabel = UILabel()
    var plotDateTitleLabel = UILabel()
    var plotOpenPriceLabel = UILabel()
    var plotOpenPriceTitleLabel = UILabel()
    var plotClosePriceLabel = UILabel()
    var plotClosePriceTitleLabel = UILabel()
    var plotHighPriceLabel = UILabel()
    var plotHighPriceTitleLabel = UILabel()
    var plotLowPriceLabel = UILabel()
    var plotLowPriceTitleLabel = UILabel()
    lazy var plotInfo:UIStackView = {
        
        let stacklineContainer = UIStackView()
        let stacklineL = UIStackView()
        let stacklineR = UIStackView()
        let stacklineTop = UIStackView()
        let stacklineBtm = UIStackView()
        stacklineContainer.axis = .horizontal
        stacklineContainer.distribution = .fillProportionally
        stacklineContainer.spacing = 10
        stacklineContainer.addArrangedSubview(stacklineL)
        stacklineContainer.addArrangedSubview(stacklineR)
        
        stacklineR.addArrangedSubview(stacklineTop)
        stacklineR.addArrangedSubview(stacklineBtm)
        stacklineL.axis = .horizontal
        stacklineR.axis = .vertical
        stacklineTop.axis = .horizontal
        stacklineTop.distribution = .fillEqually
        stacklineBtm.axis = .horizontal
        stacklineBtm.distribution = .fillEqually
        plotDateTitleLabel.text = "日期："
        plotOpenPriceTitleLabel.text = "開盤："
        plotClosePriceTitleLabel.text = "收盤："
        plotHighPriceTitleLabel.text = "高："
        plotLowPriceTitleLabel.text = "低："
        plotDateTitleLabel.font = UIFont.systemFont(ofSize: 12)
        plotOpenPriceTitleLabel.font = UIFont.systemFont(ofSize: 12)
        plotClosePriceTitleLabel.font = UIFont.systemFont(ofSize: 12)
        plotHighPriceTitleLabel.font = UIFont.systemFont(ofSize: 12)
        plotLowPriceTitleLabel.font = UIFont.systemFont(ofSize: 12)
        plotDateLabel.font = UIFont.systemFont(ofSize: 14)
        plotOpenPriceLabel.font = UIFont.systemFont(ofSize: 14)
        plotClosePriceLabel.font = UIFont.systemFont(ofSize: 14)
        plotHighPriceLabel.font = UIFont.systemFont(ofSize: 14)
        plotLowPriceLabel.font = UIFont.systemFont(ofSize: 14)
        
        stacklineL.addArrangedSubview(plotDateTitleLabel)
        stacklineL.addArrangedSubview(plotDateLabel)
        stacklineTop.addArrangedSubview(plotOpenPriceTitleLabel)
        stacklineTop.addArrangedSubview(plotOpenPriceLabel)
        stacklineTop.addArrangedSubview(plotClosePriceTitleLabel)
        stacklineTop.addArrangedSubview(plotClosePriceLabel)
        stacklineBtm.addArrangedSubview(plotHighPriceTitleLabel)
        stacklineBtm.addArrangedSubview(plotHighPriceLabel)
        stacklineBtm.addArrangedSubview(plotLowPriceTitleLabel)
        stacklineBtm.addArrangedSubview(plotLowPriceLabel)
        
        return stacklineContainer
    }()
    
    
    lazy var overviewInfo: UIView = {
        let container = UIView()
        let stack = UIStackView()
        let stackOfTitle = UIStackView()
        
        let title = UILabel()
        title.text = "detailVC_overview_title".localized
        title.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.addArrangedSubview(totalAssetValueLabel)
        stack.addArrangedSubview(totalAmountLabel)
        stack.addArrangedSubview(avgBuyPriceLabel)
        stack.addArrangedSubview(avgSellPriceLabel)
        totalAssetValueLabel.font = UIFont.systemFont(ofSize: 14)
        totalAmountLabel.font = UIFont.systemFont(ofSize: 14)
        avgBuyPriceLabel.font = UIFont.systemFont(ofSize: 14)
        avgSellPriceLabel.font = UIFont.systemFont(ofSize: 14)
        stackOfTitle.axis = .horizontal
        stackOfTitle.distribution = .fillEqually
        stackOfTitle.addArrangedSubview(totalAssetValueTitleLabel)
        stackOfTitle.addArrangedSubview(totalAmountTitleLabel)
        stackOfTitle.addArrangedSubview(avgBuyPriceTitleLabel)
        stackOfTitle.addArrangedSubview(avgSellPriceTitleLabel)
        totalAssetValueTitleLabel.text = "市值"
        totalAmountTitleLabel.text = "持股數"
        avgBuyPriceTitleLabel.text = "買入均價"
        avgSellPriceTitleLabel.text = "賣出均價"
        totalAssetValueTitleLabel.font = UIFont.systemFont(ofSize: 14)
        totalAmountTitleLabel.font = UIFont.systemFont(ofSize: 14)
        avgBuyPriceTitleLabel.font = UIFont.systemFont(ofSize: 14)
        avgSellPriceTitleLabel.font = UIFont.systemFont(ofSize: 14)
        
        totalAssetValueTitleLabel.textAlignment = .center
        totalAmountTitleLabel.textAlignment = .center
        avgBuyPriceTitleLabel.textAlignment = .center
        avgSellPriceTitleLabel.textAlignment = .center
        totalAssetValueLabel.textAlignment = .center
        totalAmountLabel.textAlignment = .center
        avgBuyPriceLabel.textAlignment = .center
        avgSellPriceLabel.textAlignment = .center
        container.addSubview(stack)
        container.addSubview(stackOfTitle)
        container.addSubview(title)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        stackOfTitle.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            title.topAnchor.constraint(equalTo: container.topAnchor),
            stackOfTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackOfTitle.topAnchor.constraint(equalTo: title.bottomAnchor),
            stackOfTitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.topAnchor.constraint(equalTo: stackOfTitle.bottomAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }()
    var totalAssetValueLabel = UILabel()
    var totalAmountLabel = UILabel()
    var avgBuyPriceLabel = UILabel()
    var avgSellPriceLabel = UILabel()
    var totalAssetValueTitleLabel = UILabel()
    var totalAmountTitleLabel = UILabel()
    var avgBuyPriceTitleLabel = UILabel()
    var avgSellPriceTitleLabel = UILabel()
    @IBOutlet weak var containerTableView: UITableView!
    
    func configure(with viewModel: StockDetailViewModel) {
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindViewModel()
        combinedChartView.delegate = self
        combinedChartView.dragEnabled = true
        combinedChartView.setScaleEnabled(true)
        combinedChartView.pinchZoomEnabled = true
        
        // 启用水平滚动
        combinedChartView.dragXEnabled = true
        
        
        //        combinedChartView.dragYEnabled = false
        // 添加观察者来监听滚动
        navigationItem.title = "\(stockName ?? "") \(viewModel.stockNo ?? "")"
        
        let newsButton = UIBarButtonItem(title: "detailVC_news_title".localized, style: .plain, target: self, action: #selector(navigateToNews))
        let addHistoryButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showAlertForDestination))
        let chatRoomButton = UIBarButtonItem(image: UIImage(systemName: "message"), style: .plain, target: self, action: #selector(navigateToChatRoom))
        navigationItem.rightBarButtonItems = [addHistoryButton, newsButton, chatRoomButton]
        
        // custom table header
        setTableHeader()
        
        containerTableView.dataSource = self
        containerTableView.delegate = self
        containerTableView.showsVerticalScrollIndicator = false
        // rigister custom section header
        containerTableView.register(MyCustomSectionHeader.self, forHeaderFooterViewReuseIdentifier: "sectionHeader")
        // custom tableview cell
        containerTableView.register(UINib(nibName: "NewHistoryTableViewCell", bundle: nil), forCellReuseIdentifier: NewHistoryTableViewCell.identifier)
        
    }
    func setTableHeader() {
        stockPriceLabel.text = stockPrice
        timeLabel.text = timeString
        timeLabel.textColor = .systemGray
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.size.height*0.5))
        header.addSubview(priceContainerView)
        header.addSubview(combinedChartView)
        header.addSubview(overviewInfo)
        header.addSubview(plotInfo)
        priceContainerView.addSubview(priceDiffLabel)
        priceContainerView.addSubview(arrowImageView)
        priceContainerView.addSubview(stockPriceLabel)
        priceContainerView.addSubview(timeLabel)
        priceContainerView.translatesAutoresizingMaskIntoConstraints = false
        priceDiffLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        stockPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        combinedChartView.translatesAutoresizingMaskIntoConstraints = false
        overviewInfo.translatesAutoresizingMaskIntoConstraints = false
        plotInfo.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([ priceContainerView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                                      priceContainerView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                                      priceContainerView.topAnchor.constraint(equalTo: header.topAnchor),
                                      priceContainerView.heightAnchor.constraint(equalToConstant: 20),
                                      stockPriceLabel.leadingAnchor.constraint(equalTo: priceContainerView.leadingAnchor),
                                      stockPriceLabel.centerYAnchor.constraint(equalTo: priceContainerView.centerYAnchor),
                                      arrowImageView.leadingAnchor.constraint(equalTo: stockPriceLabel.trailingAnchor),
                                      arrowImageView.centerYAnchor.constraint(equalTo: priceContainerView.centerYAnchor),
                                      priceDiffLabel.leadingAnchor.constraint(equalTo: arrowImageView.trailingAnchor),
                                      priceDiffLabel.centerYAnchor.constraint(equalTo: priceContainerView.centerYAnchor),
                                      timeLabel.trailingAnchor.constraint(equalTo: priceContainerView.trailingAnchor),
                                      timeLabel.centerYAnchor.constraint(equalTo: priceContainerView.centerYAnchor),
                                      combinedChartView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                                      combinedChartView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                                      combinedChartView.topAnchor.constraint(equalTo: priceContainerView.bottomAnchor),
                                      //                                      combinedChartView.heightAnchor.constraint(equalToConstant: 300),
                                      combinedChartView.heightAnchor.constraint(equalTo: header.heightAnchor, multiplier: 0.7),
                                      plotInfo.topAnchor.constraint(equalTo: combinedChartView.bottomAnchor),
                                      plotInfo.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                                      plotInfo.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                                      plotInfo.heightAnchor.constraint(equalToConstant: 30),
                                      overviewInfo.topAnchor.constraint(equalTo: plotInfo.bottomAnchor),
                                      overviewInfo.bottomAnchor.constraint(equalTo: header.bottomAnchor),
                                      overviewInfo.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                                      overviewInfo.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                                      overviewInfo.heightAnchor.constraint(lessThanOrEqualTo: header.heightAnchor, multiplier: 0.2),
                                      
                                    ])
        containerTableView.tableHeaderView = header
    }
    class MyCustomSectionHeader: UITableViewHeaderFooterView {
        let title: UILabel = {
            let label = UILabel()
            label.text = "detailVC_history_title".localized
            label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            return label
        }()
        let label1: UILabel = {
            let label = UILabel()
            label.text = "買/賣"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            return label
        }()
        let label2: UILabel = {
            let label = UILabel()
            label.text = "日期"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            return label
        }()
        let label3: UILabel = {
            let label = UILabel()
            label.text = "價位"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            return label
        }()
        let label4: UILabel = {
            let label = UILabel()
            label.text = "股數"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            return label
        }()
        let label5: UILabel = {
            let label = UILabel()
            label.text = "損益"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            return label
        }()
        lazy var stack: UIStackView = {
            let stack = UIStackView()
            stack.addArrangedSubview(label1)
            stack.addArrangedSubview(label2)
            stack.addArrangedSubview(label3)
            stack.addArrangedSubview(label4)
            stack.addArrangedSubview(label5)
            stack.axis = .horizontal
            stack.distribution = .fillEqually
            return stack
        }()
        
        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            
            configure()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        func configure() {
            title.translatesAutoresizingMaskIntoConstraints = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(title)
            contentView.addSubview(stack)
            NSLayoutConstraint.activate([title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                                         title.topAnchor.constraint(equalTo: contentView.topAnchor),
                                         stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                                         stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                                         stack.topAnchor.constraint(equalTo: title.bottomAnchor),
                                         stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                                        ])
        }
        
    }
    @objc func navigateToAddRecord() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "addRecordController") as! AddHistoryViewController
        destinationController.stockNo = viewModel.stockNo
        navigationController?.pushViewController(destinationController, animated: true)
    }
    func navigateToDividendVC() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "dividendVC") as! AddDividendViewController
        destinationController.stockNo = viewModel.stockNo
        navigationController?.pushViewController(destinationController, animated: true)
    }
    @objc func showAlertForDestination() {
        let alertVC = UIAlertController()
        let actionTrade = UIAlertAction(title: "買/賣", style: .default) { _ in
            self.navigateToAddRecord()
        }
        let actionDividend = UIAlertAction(title: "股利", style: .default) { _ in
            self.navigateToDividendVC()
        }
        let actionCancel = UIAlertAction(title: "取消", style: .cancel)
        alertVC.addAction(actionTrade)
        alertVC.addAction(actionDividend)
        alertVC.addAction(actionCancel)
        
        present(alertVC, animated: false, completion: nil)
    }
    @objc func navigateToNews() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "newsListVC") as! NewsListViewController
        destinationController.stockName = self.stockName
        
        navigationController?.pushViewController(destinationController, animated: true)
    }
    @objc func navigateToChatRoom() {
        
        let chatRoomVC = ChatViewController(stockNo: viewModel.stockNo)
        navigationController?.pushViewController(chatRoomVC, animated: true)
    }
    override func viewWillAppear(_ animated: Bool) {
        
        Task {
            await viewModel.fetchRemoteData(to: combinedChartView)
        }
        viewModel.fetchDB()
        
        navigationItem.largeTitleDisplayMode = .always
        
    }
    
    
    func bindViewModel() {
        
        viewModel.stockInfoForCandleStickChartCombine
            .sink { [weak self] data in
                self?.stockInfoForCandleStickChart = data
            }.store(in: &subscription)
        
        viewModel.historyCombine
            .sink {  [weak self] history in
                self?.containerTableView.reloadData()
            }.store(in: &subscription)
        
        viewModel.$highlightChartIndex
            .sink { [weak self] index in
                logger.debug("index=\(index)")
                self?.combinedChartView.highlightValue(x: Double(index), dataSetIndex: 0, dataIndex: 1)
                self?.combinedChartView.layoutIfNeeded()
            }
            .store(in: &subscription)
        
        viewModel.totalAmountCombine
            .sink { [weak self] amount in
                self?.totalAmountLabel.text = "\(amount)"
            }
            .store(in: &subscription)
        
        viewModel.avgBuyPriceCombine
            .sink { [weak self] price in
                guard let priceFloat = Float(price) else { return }
                self?.avgBuyPriceLabel.text = priceFloat>0 ? price : "-"
            }
            .store(in: &subscription)
        
        viewModel.avgSellPriceCombine
            .sink { [weak self] price in
                guard let priceFloat = Float(price) else { return }
                self?.avgSellPriceLabel.text = priceFloat>0 ? price : "-"
            }
            .store(in: &subscription)
        
        viewModel.totalAssetCombine
            .sink { [weak self] value in
                self?.totalAssetValueLabel.text = value
            }
            .store(in: &subscription)
        
    }
    func outputTimeString() -> String {
        let currentDate = Date()
        let formatter = DateFormatter()
        //        formatter.dateFormat = "MM-dd HH:mm"
        formatter.dateFormat = "MM-dd"
        let _ = Calendar.current.component(.weekday, from: currentDate)
        let _ = Calendar.current.component(.hour, from: currentDate)
        
        let string = formatter.string(from: currentDate)
        
        return string
    }
}


extension StockViewController: ChartViewDelegate {
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
        let index = Int(highlight.x)
        plotDateLabel.text = "\(stockInfoForCandleStickChart[index][0])"
        plotOpenPriceLabel.text = "\(stockInfoForCandleStickChart[index][3])"
        plotClosePriceLabel.text = "\(stockInfoForCandleStickChart[index][6])"
        plotHighPriceLabel.text = "\(stockInfoForCandleStickChart[index][4])"
        plotLowPriceLabel.text = "\(stockInfoForCandleStickChart[index][5])"
        
    }
    // 使用 Charts 提供的代理方法偵測滑動
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        guard let combinedChart = chartView as? CombinedChartView else { return }
        
        // 使用 getTransformer() 來獲取當前可見的 X 軸範圍
        let transformer = combinedChart.getTransformer(forAxis: .left)
        let viewPort = transformer.valueForTouchPoint(CGPoint(x: combinedChart.bounds.minX, y: 0))
        let currentOffset = viewPort.x
        
        if currentOffset < lastContentOffset {
            print("使用者正在向左滑動（往 -X 方向）")
            handleNegativeXScroll(combinedChart)
        }
        
        lastContentOffset = currentOffset
    }
    
    
    private func handleNegativeXScroll(_ chartView: CombinedChartView) {
        // 使用 getTransformer 獲取可見範圍
        let transformer = chartView.getTransformer(forAxis: .left)
        let leftPoint = transformer.valueForTouchPoint(CGPoint(x: chartView.bounds.minX, y: 0))
        let rightPoint = transformer.valueForTouchPoint(CGPoint(x: chartView.bounds.maxX, y: 0))
        
        // 如果接近左邊界，載入更多資料
        if leftPoint.x <= 1 {  // 可以依需求調整這個閾值
            print("沒了")
            //            loadMoreHistoricalData()
        }
    }
        
    func loadMoreHistoricalData() {
        // 在這裡實作載入更多歷史資料的邏輯
        // 例如：
        // 1. 從伺服器取得更多資料
        // 2. 更新圖表資料
        let newData = CombinedChartData() // 建立新的資料
        // 設定新的資料...
        combinedChartView.data = newData
        combinedChartView.notifyDataSetChanged()
    }
}


extension StockViewController: UITableViewDataSource, UITableViewDelegate {
    // custom header section, delegate method
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = containerTableView.dequeueReusableHeaderFooterView(withIdentifier: "sectionHeader") as! MyCustomSectionHeader
        return view
    }
    // header section height
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return viewModel.historyCombine.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = containerTableView.dequeueReusableCell(withIdentifier: NewHistoryTableViewCell.identifier, for: indexPath) as! NewHistoryTableViewCell
        let historyViewModel = viewModel.historyCombine.value[indexPath.row]
        cell.configure(with: historyViewModel)
        cell.selectionStyle = .none
        return cell
    }
    
    // MARK: click table cell to highlight on chart
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.findClickHistoryDate(index: indexPath.row)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        containerTableView.setEditing(editing, animated: true)
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            viewModel.deleteHistory(at: indexPath.row)
        }
    }
    
    
}




