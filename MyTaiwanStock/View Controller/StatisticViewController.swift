//
//  StatisticViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/1/5.
//
import CoreData
import Charts
import UIKit

class StatisticViewController: UIViewController {
    var chartService: ChartService!
    var stockNoToAsset: [StockStatistic] = []
    @IBOutlet weak var pieChartView: PieChartView!
    @IBOutlet weak var tableView: UITableView!
    var context: NSManagedObjectContext?
    lazy var fetchedResultsController: NSFetchedResultsController<InvestHistory> = {
    
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)

        fetchRequest.sortDescriptors = [sortDescriptor]

        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
       
        
        return frc
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        pieChartView.delegate = self
        tableView.dataSource = self
        tableView.delegate = self

    }
    override func viewWillAppear(_ animated: Bool) {
        do {
            try fetchedResultsController.performFetch()
     
            // [[stockNo: 0050, amount: 100...],[stockNo: 0050, amount: 20...]] -> [0050: 120]
            var stockNoToAmountList = [String: Int]()
            var stockNoToPriceList = [String: Double]()
            if let historyList = fetchedResultsController.fetchedObjects {
                
                historyList.map { history in
                    //print("history...\(history)")
                    if stockNoToAmountList[history.stockNo!] == nil {
                        stockNoToAmountList[history.stockNo!] = Int(history.amount) * (history.status == 0 ? 1 : -1)
                    } else {
                        stockNoToAmountList[history.stockNo!]! += Int(history.amount) * (history.status == 0 ? 1 : -1)
                    }
                }
                //print("stockNoToAmountList...\(stockNoToAmountList)")
                

                let savedStockPrice = OneDayStockInfo.priceList
                //print("userDefault...stockPrice...\(savedStockPrice)")
                savedStockPrice.map { stock in
                    stockNoToPriceList[stock.stockNo] = stock.current != "-" ? Double(stock.current) : Double(stock.yesterDayPrice)
                }
                //print("stockNoToPriceList...\(stockNoToPriceList)")

                stockNoToAsset = stockNoToAmountList.map({ (key: String, value: Int) in
                    StockStatistic(stockNo: key, totalAssets: Double(value) * stockNoToPriceList[key]! )
                })
                tableView.reloadData()
                //print("stockNoToAsset...\(stockNoToAsset)")
                
                
            }
            if stockNoToAsset.isEmpty {
                self.showWarningPopup()
            }
            // chart
            self.chartService = ChartService(pieChartData: self.stockNoToAsset)
            chartService.prepareForPieChart(pieChartView: pieChartView)
        } catch {
            fatalError("Invest history fetch error")
        }
    }
    func showWarningPopup() {

        let alertVC = UIAlertController(title: "Remind", message: "Please add some invest history!", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
            self.tabBarController?.selectedIndex = 0
        }
        alertVC.addAction(okAction)
        self.present(alertVC, animated: true, completion: nil)
    }
 


}

extension StatisticViewController: ChartViewDelegate {
    
}

extension StatisticViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stockNoToAsset.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "statisticCell", for: indexPath) as! StatisticTableViewCell
        
        cell.update(with: stockNoToAsset[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}
