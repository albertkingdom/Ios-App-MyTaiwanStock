//
//  StockViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/4.
//

import UIKit
import Charts

class StockViewController: UIViewController {

    @IBAction func addRecord(_ sender: Any) {
        
    }
    @IBOutlet weak var candleStickChartView: CandleStickChartView!
    var stockInfoForCandleStickChart: [[String]]!
    var stockNo: String!
    var history: [History]!
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
        
        navigationItem.title = stockNo
      print("stockview viewdidload")
        
        
    }
    override func viewWillAppear(_ animated: Bool) {
        /*
        StockInfo.fetchStockInfo(stockNo: stockNo){ result in
            switch result {
            case .success(let stockInfo):
                self.stockInfoForCandleStickChart = stockInfo.data

                DispatchQueue.main.async {
                    if self.stockInfoForCandleStickChart != nil{
                        self.prepareForChart()
                    }
                }
                
               
            case .failure(let error):
                print("failure: \(error)")
            }
        
        }*/
        print("stockview viewwillappear")
        history = HistoryList.loadFromDisk().filter({ history in
            history.stockNo == self.stockNo
        })
        StockInfo.fetchTwoMonth(stockNo: stockNo) { data in
            self.stockInfoForCandleStickChart = data
            DispatchQueue.main.async {
                
                if self.stockInfoForCandleStickChart != nil{
                    self.prepareForChart()
                }
            }
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
    
    
    /// navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination as! AddHistoryViewController
        destination.history = self.history
        destination.stockNo = self.stockNo
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
        return history.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath) as! HistoryTableViewCell
        
        
        cell.update(with: history[indexPath.row], stockPrice: stockPrice)

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
            let itemToDelete = history[indexPath.row]
            
            history.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // TODO: save list to disk
        }
    }
}
