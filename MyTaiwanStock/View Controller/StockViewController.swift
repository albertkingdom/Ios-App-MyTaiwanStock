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
    

    @IBOutlet weak var combinedChartView: CombinedChartView!
    var stockInfoForCandleStickChart: [[String]]!
    var stockNo: String!
    var stockName: String!
    var stockPrice: String!
    private let database = Firestore.firestore()

    var isHideKplot: Bool = false {
        didSet {
            if !isHideKplot {
                kplotHeight.constant = 300
                
                showOrHideButton.setImage(UIImage(systemName: "arrow.up.to.line"), for: .normal)
            } else {
                kplotHeight.constant = 0
                showOrHideButton.setImage(UIImage(systemName: "arrow.down.to.line"), for: .normal)
            }
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
            
        }
    }
    @IBOutlet weak var dateView: UILabel!
    @IBOutlet weak var openPriceView: UILabel!
    @IBOutlet weak var closePriceView: UILabel!
    @IBOutlet weak var highPriceView: UILabel!
    @IBOutlet weak var lowPriceView: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var kplotHeight: NSLayoutConstraint!
    @IBOutlet weak var showOrHideButton: UIButton!
    @IBAction func touchHideKplotButton(_ sender: Any) {
       
        isHideKplot = !isHideKplot

      
    }
    @IBOutlet weak var historyContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = StockDetailViewModel(stockNo: stockNo, currentStockPrice: stockPrice, context: context)

        combinedChartView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none// remove unused separator

        navigationItem.title = stockNo
       
        let newsButton = UIBarButtonItem(title: "News", style: .plain, target: self, action: #selector(navigateToNews))
        let addHistoryButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(navigateToAddRecord))
        let chatRoomButton = UIBarButtonItem(image: UIImage(systemName: "message"), style: .plain, target: self, action: #selector(navigateToChatRoom))
        navigationItem.rightBarButtonItems = [addHistoryButton, newsButton, chatRoomButton]
        
        
        
        bindViewModel()

        tableView.backgroundColor = .secondarySystemBackground
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
        viewModel.stockInfoForCandleStickChart.bind { data in
            self.stockInfoForCandleStickChart = data
        }

        viewModel.historyCombine.sink {  [weak self] history in
            print("history \(history.count)")
            self?.tableView.reloadData()
        }.store(in: &subscription)
        
        viewModel.$highlightChartIndex.sink { [weak self] index in
            self?.combinedChartView.highlightValue(x: Double(index), dataSetIndex: 0, dataIndex: 1)
            self?.combinedChartView.layoutIfNeeded()
        }
        .store(in: &subscription)
    }
}


extension StockViewController: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {

        
        let index = Int(highlight.x)
        dateView.text = "日期：\(stockInfoForCandleStickChart[index][0])"
        openPriceView.text = "開盤：\(stockInfoForCandleStickChart[index][3])"
        closePriceView.text = "收盤：\(stockInfoForCandleStickChart[index][6])"
        highPriceView.text = "最高：\(stockInfoForCandleStickChart[index][4])"
        lowPriceView.text = "最低：\(stockInfoForCandleStickChart[index][5])"
        
    }

}


extension StockViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return viewModel.historyCombine.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath) as! HistoryTableViewCell

        let historyViewModel = viewModel.historyCombine.value[indexPath.row]
        cell.configure(with: historyViewModel)
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
        tableView.setEditing(editing, animated: true)
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




