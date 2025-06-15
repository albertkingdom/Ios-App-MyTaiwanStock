//
//  ChartService.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/4/14.
//
import UIKit
import Foundation
import Charts

class ChartService {
    var stockInfoForCandleStickChart: [[String]]?
    var stockNo: String?
    var stockNoObjects: [StockNo]?
    var pieChartData: [StockStatistic]?
    var historyList: [InvestHistory]?
    var stockPriceList: [OneDayStockInfoDetail]?
    
    // constructor for candle stick chart
    init(candleStickData: [[String]], stockNo: String) {
        self.stockInfoForCandleStickChart = candleStickData
        self.stockNo = stockNo
    }
    // constructor for pie chart
    init(pieChartData: [StockStatistic]) {
        self.pieChartData = pieChartData
    }

    init(historyList: [InvestHistory], stockNoObjects: [StockNo]) {
        self.historyList = historyList
        self.stockNoObjects = stockNoObjects
    }
    func generateCandleData(stockInfoForCandleStickChart: [[String]], stockNo: String) -> CandleChartData {
        let candleStickEntries = stockInfoForCandleStickChart.enumerated().map { (index, day) in

            let shadowH = Double(day[4]) ?? 0.0
            let shadowL = Double(day[5]) ?? 0.0
            let open = Double(day[3]) ?? 0.0
            let close = Double(day[6]) ?? 0.0
            return CandleChartDataEntry.init(x: Double(index), shadowH: shadowH, shadowL: shadowL, open: open, close: close)
        }
        
        
        
        
        let candleDataSet = CandleChartDataSet(entries: candleStickEntries, label: stockNo)
        
        candleDataSet.shadowColor = UIColor.black
        candleDataSet.decreasingColor = UIColor.systemGreen
        candleDataSet.decreasingFilled = true
        candleDataSet.increasingColor = UIColor.red
        candleDataSet.increasingFilled = true
        candleDataSet.neutralColor = UIColor.black
        candleDataSet.drawValuesEnabled = false
        candleDataSet.axisDependency = YAxis.AxisDependency.left
        candleDataSet.showCandleBar = true
        
        candleDataSet.highlightColor = NSUIColor.systemYellow
        let candleData = CandleChartData(dataSet: candleDataSet)
        return candleData
    }
    
    private func calculateAverageEntries(candleEntries: [CandleChartDataEntry], windowSize: Int=5) -> [ChartDataEntry] {
        var averageEntries = [ChartDataEntry]()

        for i in (windowSize - 1)..<candleEntries.count {
            let start = i - windowSize + 1
            let end = i + 1
            let sum = candleEntries[start..<end].reduce(0.0) { $0 + $1.close }
            let average = sum / Double(windowSize)
            averageEntries.append(ChartDataEntry(x: Double(Float(i)), y: Double(Float(average))))
        }
        
        return averageEntries
    }
    func generateBarData(stockInfoForCandleStickChart: [[String]]) -> BarChartData {
        let barEntries = stockInfoForCandleStickChart.enumerated().map({ (index, day) -> BarChartDataEntry in
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let number = formatter.number(from: day[2])
            
            return BarChartDataEntry(x: Double(index), y: Double(truncating: number!))
            
        })
        let barDataSet = BarChartDataSet(entries: barEntries, label: "volume")
        barDataSet.drawValuesEnabled = false
        barDataSet.axisDependency = YAxis.AxisDependency.right
        barDataSet.setColor(NSUIColor.lightGray)
        
        let barData = BarChartData(dataSet: barDataSet)
        
        return barData
    }
    func generateXLabel(data: [[String]]) -> [String] {
        data.enumerated().map {
            (index, day) in
            String(day[0])
        }
    }
    func prepareForCombinedChart(combinedChartView: CombinedChartView) {
        let xLabels: [String] = generateXLabel(data: self.stockInfoForCandleStickChart!)
        
        
        combinedChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xLabels)
        combinedChartView.xAxis.labelPosition = XAxis.LabelPosition.bottom
        combinedChartView.xAxis.labelRotationAngle = -25
        combinedChartView.legend.enabled = false
        combinedChartView.setScaleEnabled(false)
        combinedChartView.dragEnabled = true
        //        candleStickChartView.extraBottomOffset = 50
        combinedChartView.xAxis.drawGridLinesEnabled = false
        combinedChartView.drawBordersEnabled = true
        //        candleStickChartView.borderLineWidth = 0.5
        combinedChartView.rightAxis.enabled = true
        combinedChartView.backgroundColor = .systemBackground
        combinedChartView.drawOrder = [CombinedChartView.DrawOrder.bar.rawValue, CombinedChartView.DrawOrder.candle.rawValue]
        
        let rightYaxis = combinedChartView.rightAxis
        rightYaxis.valueFormatter = LargeValueFormatter()
        
        rightYaxis.spaceTop = 5 // space height from top of max value to total height
        rightYaxis.drawGridLinesEnabled = false
        
        let combinedData = CombinedChartData()
        combinedData.isHighlightEnabled = true
        
        guard let stockInfoForCandleStickChart = stockInfoForCandleStickChart, let stockNo = stockNo else {return}
       
        combinedData.barData = self.generateBarData(stockInfoForCandleStickChart: stockInfoForCandleStickChart)
        let candleDatas: CandleChartData = self.generateCandleData(stockInfoForCandleStickChart: stockInfoForCandleStickChart, stockNo: stockNo)
        combinedData.candleData = candleDatas
        if let candleData = combinedData.candleData {
            if let dataSet = candleData.dataSets.first as? CandleChartDataSet {
                // Get all candle entries
                let candleEntries = dataSet.entries as! [CandleChartDataEntry]
                let averageEntriesFiveDays = calculateAverageEntries(candleEntries: candleEntries)
                let averageEntriesTenDays = calculateAverageEntries(candleEntries: candleEntries, windowSize: 10)
                let averageDataSetFiveDays = LineChartDataSet(entries: averageEntriesFiveDays, label: "Average 5")
                let averageDataSetTenDays = LineChartDataSet(entries: averageEntriesTenDays, label: "Average 10")
                averageDataSetFiveDays.colors=[UIColor(hex:"#ffcc00")]
                averageDataSetFiveDays.lineWidth=0.5
                averageDataSetFiveDays.drawValuesEnabled = false
                averageDataSetFiveDays.drawCirclesEnabled = false
                averageDataSetTenDays.colors=[UIColor(hex:"#e238ec")]
                averageDataSetTenDays.lineWidth=0.5
                averageDataSetTenDays.drawValuesEnabled = false
                averageDataSetTenDays.drawCirclesEnabled = false

                let lineData = LineChartData(dataSets:  [averageDataSetFiveDays, averageDataSetTenDays])
                combinedData.lineData=lineData

            }
        }
        // draw order
        combinedChartView.drawOrder = [CombinedChartView.DrawOrder.bar.rawValue,
                                       CombinedChartView.DrawOrder.candle.rawValue,
                                       CombinedChartView.DrawOrder.line.rawValue]

        combinedData.candleData.isHighlightEnabled = true
        combinedData.barData.isHighlightEnabled = false
        combinedChartView.data = combinedData
        
        combinedChartView.notifyDataSetChanged()
        
        // 顯示幾個數據點
        combinedChartView.setVisibleXRangeMaximum(20) // 必須先有資料
        
        guard let totalCandleCount = combinedData.candleData.dataSets.first?.entryCount else {return}
        combinedChartView.moveViewToX(Double(totalCandleCount-10))
    }
    
    func prepareForPieChart(pieChartView: PieChartView) {
        guard let pieChartData = pieChartData else {
            return
        }
        // entries -> pieDataset -> pieData -> pieChart
        
        let colors:[UIColor] = pieChartData.map { entry in
            return UIColor(red: CGFloat(Float.random(in: 0..<1)), green: CGFloat(Float.random(in: 0..<1)), blue: CGFloat(Float.random(in: 0..<1)), alpha: 1)
        }
        var entries: [PieChartDataEntry] = []
        
        let pieDataSet: PieChartDataSet
        let pieData: PieChartData
        
        let sumOfAsset = pieChartData.map { entry in
            entry.totalAssets
        }.reduce(0) { partialResult, item in
            partialResult + item
        }
        
        
        //print("sumOfAsset..\(sumOfAsset)")
        entries = pieChartData.map({
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
        
        pieChartView.data = pieData
        pieChartView.usePercentValuesEnabled = true
        
    }
    

    
    func calculateStockNoToAsset2() -> [StockStatistic]? {
        guard let historyList = historyList else {
            return nil
        }
        guard let stockPriceList = stockNoObjects else {
            return nil
        }

        
        var stockNoToAmountList = [String: Int]()
        var stockNoToPriceList = [String: Double]()
        
        
        let _ = historyList.map { history in
            //print("history...\(history)")
            if stockNoToAmountList[history.stockNo!] == nil {
                stockNoToAmountList[history.stockNo!] = Int(history.amount) * (history.status == 0 ? 1 : -1)
            } else {
                stockNoToAmountList[history.stockNo!]! += Int(history.amount) * (history.status == 0 ? 1 : -1)
            }
        }
        //print("stockNoToAmountList...\(stockNoToAmountList)")

        let _ = stockPriceList.map { stock in
            guard let stockNoString = stock.stockNo else {
                return
            }
            let currentPrice = stock.currentPrice

            stockNoToPriceList[stockNoString] = currentPrice
        }
        //print("stockNoToPriceList...\(stockNoToPriceList)")
        
        let stockNoToAsset = stockNoToAmountList.map({ (key: String, value: Int) -> StockStatistic in
            
            return StockStatistic(stockNo: key,
                                  stockAmount: value,
                                  totalAssets: Double(value) * (stockNoToPriceList[key] ?? 0))
            
        })
        //print("chartsevice stockNoToAsset..\(stockNoToAsset)")
        pieChartData = stockNoToAsset
        let filteredNonzeroTotalAsset = stockNoToAsset.filter {
            $0.totalAssets > 0
        }
        return filteredNonzeroTotalAsset
    }
}
