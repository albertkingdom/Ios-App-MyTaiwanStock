//
//  StockViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/4.
//
import CoreData
import UIKit
import Charts

class StockViewController: UIViewController {
    var context: NSManagedObjectContext?
    lazy var fetchedResultsController: NSFetchedResultsController<InvestHistory> = {
    
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)
        let predicate = NSPredicate(format: "stockNo == %@", self.stockNo!)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = predicate
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
        frc.delegate = self
        return frc
    }()
    

    @IBOutlet weak var candleStickChartView: CandleStickChartView!
    var stockInfoForCandleStickChart: [[String]]!
    var stockNo: String!
    var stockName: String!
    var stockPrice: String!
    @IBOutlet weak var dateView: UILabel!
    @IBOutlet weak var openPriceView: UILabel!
    @IBOutlet weak var closePriceView: UILabel!
    @IBOutlet weak var highPriceView: UILabel!
    @IBOutlet weak var lowPriceView: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        candleStickChartView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        tabBarController?.navigationItem.title = stockNo
        tabBarController?.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(navigateToAddRecord))
     
        
        
    }
    @objc func navigateToAddRecord() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "addRecordController") as! AddHistoryViewController
        destinationController.stockNo = self.stockNo
        destinationController.context = self.context
        navigationController?.pushViewController(destinationController, animated: true)
    }
    override func viewWillAppear(_ animated: Bool) {
      
        print("stockview viewwillappear")
    
        StockInfo.fetchTwoMonth(stockNo: stockNo) { data in
            self.stockInfoForCandleStickChart = data
            DispatchQueue.main.async {
                
                if self.stockInfoForCandleStickChart != nil{
                    self.prepareForChart()
                }
            }
        }
        
        do {
            try fetchedResultsController.performFetch()
            //tableView.reloadData()
        } catch {
            fatalError("Invest history fetch error")
        }
    }
    
    
    func prepareForChart() {
        var xLabels: [String] = []
        var candleStickEntry: [CandleChartDataEntry] = []
        var candleDataSet: CandleChartDataSet
        
        // x axis label data
        xLabels = stockInfoForCandleStickChart.enumerated().map {
            (index, day) in
            String(day[0])
        }
        // y data
        candleStickEntry = stockInfoForCandleStickChart.enumerated().map({ (index, day) in
            return CandleChartDataEntry.init(x: Double(index), shadowH: Double(day[4])!, shadowL: Double(day[5])!, open: Double(day[3])!, close: Double(day[6])!)
        })
        
       
        
        
        candleDataSet = CandleChartDataSet(entries: candleStickEntry, label: "0050")
        
        candleDataSet.shadowColor = .black
        candleDataSet.decreasingColor = .systemGreen
        candleDataSet.decreasingFilled = true
        candleDataSet.increasingColor = .red
        candleDataSet.increasingFilled = true
        candleDataSet.neutralColor = .black
        candleDataSet.drawValuesEnabled = false
        
        let data = CandleChartData(dataSet: candleDataSet)
        candleStickChartView.data = data
        
        
        candleStickChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xLabels)
        candleStickChartView.xAxis.labelPosition = XAxis.LabelPosition.bottom
        candleStickChartView.xAxis.labelRotationAngle = -25
        candleStickChartView.legend.enabled = false
        candleStickChartView.setScaleEnabled(false)
        candleStickChartView.dragEnabled = true
        candleStickChartView.extraBottomOffset = 50
        candleStickChartView.xAxis.drawGridLinesEnabled = false
        candleStickChartView.drawBordersEnabled = true
        candleStickChartView.borderLineWidth = 0.5
        candleStickChartView.rightAxis.enabled = false
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
        //return history.count
        guard let sectionInfo = fetchedResultsController.sections?[section] else { return 0 }
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath) as! HistoryTableViewCell
        let cellcontent = fetchedResultsController.object(at: indexPath)
        
        cell.update(with: cellcontent, stockPrice: stockPrice)

        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //print(indexPath)
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
            
            // TODO: save list to disk
            
            let objectToDelete = fetchedResultsController.object(at: indexPath)
            context?.delete(objectToDelete)
            do {
                try context?.save()
            } catch {
                fatalError("\(error.localizedDescription)")
            }
        }
    }
}

extension StockViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let _ = anObject as? InvestHistory else {
            return
        }
        
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            guard let indexPathToDel = indexPath else { return }
            tableView.deleteRows(at: [indexPathToDel], with: .automatic)
        default:
            return
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
