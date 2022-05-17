//
//  StockDetailViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import CoreData
import Foundation
import Charts

class StockDetailViewModel {
    var context: NSManagedObjectContext?
    var stockInfoForCandleStickChart = Observable<[[String]]>(nil)
    var stockNo: String
    var currentStockPriceString: String
    var chartService: ChartService!
    var history = Observable<[HistoryCellViewModel]>([])
    var coreDataObjects: [InvestHistory]? = [] {
        didSet {
            
            guard let investHistoryList = coreDataObjects else { return }
            self.history.value = investHistoryList.map { investHostory in
                HistoryCellViewModel(historyData: investHostory, currentStockPrice: currentStockPriceString)
            }
        }
    }
    
    init(stockNo: String, currentStockPrice: String) {
        self.stockNo = stockNo
        self.currentStockPriceString = currentStockPrice
    }
    
    func fetchRemoteData(to chart: CombinedChartView) {
        StockInfo.fetchTwoMonth(stockNo: stockNo) { data in
            self.stockInfoForCandleStickChart.value = data
            DispatchQueue.main.async {
                
                if let data = self.stockInfoForCandleStickChart.value {

                    self.chartService = ChartService(candleStickData: data, stockNo: self.stockNo)
                    self.chartService.prepareForCombinedChart(combinedChartView: chart)
                }
            }
        }
    }
}
