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
//    var history = Observable<[HistoryCellViewModel]>([])
    var historyCombine = CurrentValueSubject<[HistoryCellViewModel],Never>([])
//    var coreDataObjects: [InvestHistory]? = [] {
//        didSet {
//
//            guard let investHistoryList = coreDataObjects else { return }
//            self.history.value = investHistoryList.map { investHostory in
//                HistoryCellViewModel(historyData: investHostory, currentStockPrice: currentStockPriceString)
//            }
//        }
//    }
    @Published var coreDataObjectsCombine: [InvestHistory] = []
    @Published var highlightChartIndex: Int = -1
    var subscription = Set<AnyCancellable>()
    
    init(stockNo: String, currentStockPrice: String, context: NSManagedObjectContext?) {
        self.stockNo = stockNo
        self.currentStockPriceString = currentStockPrice
        self.context = context
        setupHistoryData()
        //fetchDB()
        
        
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
       
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo == %@", self.stockNo)
        var lists: [InvestHistory] = []
        do {
            guard let result = try context?.fetch(fetchRequest) else { return }
            //print("lists \(result)")
            
            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        
        coreDataObjectsCombine = lists
       
        
    }
    
    func deleteHistory(at index: Int) {
        let itemToDelete = coreDataObjectsCombine[index]
       
        
        
        deleteHistoryInDB(historyObject: itemToDelete)
        
        coreDataObjectsCombine = coreDataObjectsCombine.filter({ object in
            object != itemToDelete
        })
    }
    // MARK: Core Data - delete
    func deleteHistoryInDB(historyObject: InvestHistory) {
        context?.delete(historyObject)
        
       
        // TODO: show the UIAlert
        try? context?.save()

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
