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
    var stockNoToAsset: [StockStatistic] = [] {
        didSet {
            tableView.reloadData()
        }
    }
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
    
            guard let historyList = fetchedResultsController.fetchedObjects else {
                showWarningPopup()
                return
            }
            let savedStockPrice = OneDayStockInfo.priceList
            
            self.chartService = ChartService(historyList: historyList, stockPriceList: savedStockPrice)
            guard let stockNoToAsset = chartService.calculateStockNoToAsset() else {
                self.showWarningPopup()
                return
            }
            //print("stockNoToAsset \(stockNoToAsset)")
            self.stockNoToAsset = stockNoToAsset
            if stockNoToAsset.isEmpty {
                self.showWarningPopup()
            }
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
