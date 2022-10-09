//
//  StockDetailViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Combine
import CoreData
import Foundation
import Charts

class StockDetailViewModel {
    var context: NSManagedObjectContext?
    var stockInfoForCandleStickChart = Observable<[[String]]>(nil)
    var stockNo: String
    var currentStockPriceString: String
    var chartService: ChartService!

    var historyCombine = CurrentValueSubject<[HistoryCellViewModel],Never>([])

    @Published var coreDataObjectsCombine: [InvestHistory] = []
    @Published var highlightChartIndex: Int = -1
    var subscription = Set<AnyCancellable>()
    var localDB: LocalDBService!
    
    init(stockNo: String, currentStockPrice: String, context: NSManagedObjectContext?) {
        self.stockNo = stockNo
        self.currentStockPriceString = currentStockPrice
        self.context = context
        setupHistoryData()
  
        self.localDB = LocalDBService(context: context)
        
        print("stock vm init")
    }
    
    func setupHistoryData() {
        $coreDataObjectsCombine
            .map { investHistoryList -> [HistoryCellViewModel] in
                
                return investHistoryList.map { investHistory in
                    HistoryCellViewModel(historyData: investHistory, currentStockPrice: self.currentStockPriceString)
                }
                
            }
            .sink { [weak self] cellViewModels in
                print("cellViewModels count \(cellViewModels.count)")
                self?.historyCombine.send(cellViewModels)
            }
            .store(in: &subscription)
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
    func fetchDB(){
       
        coreDataObjectsCombine = localDB.fetchDB(stockNo: stockNo)
    }
    
    func deleteHistory(at index: Int) {
        let itemToDelete = coreDataObjectsCombine[index]
    
        localDB.deleteHistoryInDB(historyObject: itemToDelete)
        
        coreDataObjectsCombine = coreDataObjectsCombine.filter({ object in
            object != itemToDelete
        })
    }

    
    func findClickHistoryDate(index: Int) {
        if let date = coreDataObjectsCombine[index].date {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_TW")
            dateFormatter.setLocalizedDateFormatFromTemplate("yyyy/MM/dd")
            
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            if var year = components.year, let month = components.month, let day = components.day {
                // convert date to following format like:  111/03/18
                year = year - 1911
                let fullMonth = month > 9 ? "month" : "0\(month)"
                let targetDateString = "\(year)/\(fullMonth)/\(day)"
                
                stockInfoForCandleStickChart.value?.enumerated().forEach { index, candleData in
                    // find the index of date in stockInfoForCandleStickChart
                    if candleData[0] == targetDateString {
                        
                        highlightChartIndex = index
                    }
                }
                
            }
            
        }
        
    }
    
}
