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
    var stockInfoForCandleStickChartCombine = CurrentValueSubject<[[String]], Never>([])
    var stockNo: String
    var currentStockPriceString: String
    var chartService: ChartService!

    var historyCombine = CurrentValueSubject<[HistoryCellViewModel],Never>([])
    var totalAmountCombine = CurrentValueSubject<Int, Never>(0) //持股數
    var avgBuyPriceCombine = CurrentValueSubject<String, Never>("") // 買入均價
    var avgSellPriceCombine = CurrentValueSubject<String, Never>("") //賣出均價
    var totalAssetCombine = CurrentValueSubject<String, Never>("") //市值
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
                self?.calTotalAmount(with: cellViewModels)
            }
            .store(in: &subscription)
    }
    
    func fetchRemoteData(to chart: CombinedChartView) {
        StockInfo.fetchTwoMonth(stockNo: stockNo) { data in
            //self.stockInfoForCandleStickChart.value = data
            self.stockInfoForCandleStickChartCombine.send(data)
            
            DispatchQueue.main.async {
                
                self.chartService = ChartService(candleStickData: data, stockNo: self.stockNo)
                self.chartService.prepareForCombinedChart(combinedChartView: chart)
            }
        }
    }
    func fetchDB(){
       
        coreDataObjectsCombine = localDB.fetchHistoryFromDB(with: stockNo)
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
                let fullMonth = month > 9 ? "\(month)" : "0\(month)"
                let targetDateString = "\(year)/\(fullMonth)/\(day)"
                
                stockInfoForCandleStickChartCombine.value.enumerated().forEach { index, candleData in
                    // find the index of date in stockInfoForCandleStickChart
                    if candleData[0] == targetDateString {
                        
                        highlightChartIndex = index
                    }
                }
                
            }
            
        }
        
    }
    
    func calTotalAmount(with historys: [HistoryCellViewModel]) {
        let amount = historys.map {
            guard let amountInt = Int($0.amountString) else { return 0 }
            return amountInt
        }.reduce(0) { partialResult, item in
            partialResult+item
        }
        print("amount \(amount)")
        totalAmountCombine.send(amount)
        
        let buyTotalValue = historys.filter {$0.status==0}.map { history -> Float in
            guard let amountFloat = Float(history.amountString),
                  let priceFloat = Float(history.priceString)
            else { return Float(0) }
            return amountFloat*priceFloat
        }.reduce(0) {partialResult, item in
            partialResult+item
        }
        let localAvgBuyPrice = buyTotalValue/Float(amount)
        
        let buyPriceString = String(format: "%.2f", localAvgBuyPrice)
        avgBuyPriceCombine.send(buyPriceString)
        let sellTotalValue = historys.filter {$0.status==1}.map { history -> Float in
            guard let amountFloat = Float(history.amountString),
                  let priceFloat = Float(history.priceString)
            else { return Float(0) }
            return amountFloat*priceFloat
        }.reduce(0) {partialResult, item in
            partialResult+item
        }
        let localAvgSellPrice = sellTotalValue/Float(amount)
        let sellPriceString = String(format: "%.2f", localAvgSellPrice)

        avgSellPriceCombine.send(sellPriceString)
        
        if let stockPriceFloat = Float(currentStockPriceString) {
            let assetFloat = Float(amount)*stockPriceFloat
            let assetString = String(format: "%.2f", assetFloat)

            totalAssetCombine.send(assetString)
        }
        
    }
    
    
}
