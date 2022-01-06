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
                
                //print("stockNoToAsset...\(stockNoToAsset)")
                
                
            }
            prepareForPieChart(dataSource: stockNoToAsset, target: pieChartView)
        } catch {
            fatalError("Invest history fetch error")
        }
    }
    func prepareForPieChart(dataSource: [StockStatistic], target: PieChartView) {
        // entries -> pieDataset -> pieData -> pieChart
        var colors: [UIColor] = []
        var entries: [PieChartDataEntry] = []

        let pieDataSet: PieChartDataSet
        let pieData: PieChartData
        
        colors = dataSource.map { entry in

            let randomColor = UIColor(red: CGFloat(Float.random(in: 0..<1)), green: CGFloat(Float.random(in: 0..<1)), blue: CGFloat(Float.random(in: 0..<1)), alpha: 1)
            //print(randomColor)
            return randomColor
        }
        let sumOfAsset = dataSource.map { entry in
            entry.totalAssets
        }.reduce(0) { partialResult, item in
            partialResult + item
        }
        //print("sumOfAsset..\(sumOfAsset)")
        entries = dataSource.map({
            PieChartDataEntry(value: $0.totalAssets / sumOfAsset, label: $0.stockNo)
        })
        
        pieDataSet = PieChartDataSet(entries: entries, label: "stockNo.")
        pieDataSet.colors = colors
        pieData = PieChartData(dataSet: pieDataSet)
        pieData.setDrawValues(true)
        
        let valFormatter = NumberFormatter()
        valFormatter.numberStyle = .percent
        valFormatter.percentSymbol = "%"
        valFormatter.multiplier = 1.0
        valFormatter.maximumFractionDigits = 1
        pieData.setValueFormatter(DefaultValueFormatter(formatter: valFormatter))
        pieData.setValueFont(NSUIFont.systemFont(ofSize: 12))
        
        target.data = pieData
        target.usePercentValuesEnabled = true
        
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
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}
