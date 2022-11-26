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
    var context: NSManagedObjectContext?

    var priceContainerView = UIView()
    var stockPriceLabel = UILabel()
    var arrowImageView = UIImageView()
    var priceDiffLabel = UILabel()
    var timeLabel = UILabel()
    
    var combinedChartView = CombinedChartView()
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
    var stockNo: String!
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

        let stackline1 = UIStackView()

        stackline1.axis = .horizontal
        stackline1.distribution = .fillProportionally

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

        
        stackline1.addArrangedSubview(plotDateTitleLabel)
        stackline1.addArrangedSubview(plotDateLabel)
        stackline1.addArrangedSubview(plotOpenPriceTitleLabel)
        stackline1.addArrangedSubview(plotOpenPriceLabel)
        stackline1.addArrangedSubview(plotClosePriceTitleLabel)
        stackline1.addArrangedSubview(plotClosePriceLabel)
        stackline1.addArrangedSubview(plotHighPriceTitleLabel)
        stackline1.addArrangedSubview(plotHighPriceLabel)
        stackline1.addArrangedSubview(plotLowPriceTitleLabel)
        stackline1.addArrangedSubview(plotLowPriceLabel)
        
        return stackline1
    }()
 

    lazy var overviewInfo: UIView = {
        let container = UIView()
        let stack = UIStackView()
        let stackOfTitle = UIStackView()
        
        let title = UILabel()
        title.text = "Overview"
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
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = StockDetailViewModel(stockNo: stockNo, currentStockPrice: stockPrice, context: context)
        bindViewModel()
        combinedChartView.delegate = self

        navigationItem.title = "\(stockName ?? "") \(stockNo ?? "")"
        
       
        let newsButton = UIBarButtonItem(title: "News", style: .plain, target: self, action: #selector(navigateToNews))
        let addHistoryButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(navigateToAddRecord))
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
                                      combinedChartView.heightAnchor.constraint(equalToConstant: 300),
                                      plotInfo.topAnchor.constraint(equalTo: combinedChartView.bottomAnchor),
                                      plotInfo.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                                      plotInfo.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                                      plotInfo.heightAnchor.constraint(equalToConstant: 30),
                                      overviewInfo.topAnchor.constraint(equalTo: plotInfo.bottomAnchor),
                                      overviewInfo.bottomAnchor.constraint(equalTo: header.bottomAnchor),
                                      overviewInfo.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                                      overviewInfo.trailingAnchor.constraint(equalTo: header.trailingAnchor)
                                    ])
        containerTableView.tableHeaderView = header
    }
    class MyCustomSectionHeader: UITableViewHeaderFooterView {
        let title: UILabel = {
            let label = UILabel()
            label.text = "History"
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
        destinationController.stockNo = self.stockNo
        destinationController.context = self.context
        navigationController?.pushViewController(destinationController, animated: true)
    }
    @objc func navigateToNews() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "newsListVC") as! NewsListViewController
        destinationController.stockName = self.stockName
        
        navigationController?.pushViewController(destinationController, animated: true)
    }
    @objc func navigateToChatRoom() {

        let chatRoomVC = ChatViewController(stockNo: stockNo)
        navigationController?.pushViewController(chatRoomVC, animated: true)
    }
    override func viewWillAppear(_ animated: Bool) {
      

        viewModel.fetchRemoteData(to: combinedChartView)

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




