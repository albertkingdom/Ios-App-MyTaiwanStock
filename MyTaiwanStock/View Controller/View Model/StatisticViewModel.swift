//
//  StatisticViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Combine
import CoreData
import Foundation
import Charts

class StatisticViewModel {

    var chartService: ChartService!
    var stockNoToAssetCombine = CurrentValueSubject<[StockStatistic],Never>([])
    var classifiedDividendCombine = CurrentValueSubject<[Dividend], Never>([])
    var allDividendsCombine = CurrentValueSubject<[Dividend], Never>([])
    
    lazy var fetchedResultsController: NSFetchedResultsController<InvestHistory> = {
    
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)

        fetchRequest.sortDescriptors = [sortDescriptor]

        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: LocalDBService.shared.context, sectionNameKeyPath: nil, cacheName: nil)
       
        
        return frc
    }()
    var isLoading = PassthroughSubject<Bool, Never>()
    let repository = RepositoryImpl()
    
    init(context: NSManagedObjectContext?) {
    }
    init() {}
    
    func fetchData(to chart: PieChartView) {
        do {
            try fetchedResultsController.performFetch()
    
            guard let historyList = fetchedResultsController.fetchedObjects else {
                isLoading.send(true)
                return
            }
            let stockNos = historyList.map({$0.stockNo ?? ""})
            
            let stockNoObjects = repository.fetchStockPriceFromDB(with: stockNos)
            
            self.chartService = ChartService(historyList: historyList, stockNoObjects: stockNoObjects)
            guard let stockNoToAsset = chartService.calculateStockNoToAsset2() else {
                isLoading.send(true)
                return
            }
            //print("stockNoToAsset \(stockNoToAsset)"
            self.stockNoToAssetCombine.send(stockNoToAsset)
            
            isLoading.send(false)
            prepareChart(with: chart)
        } catch {
            fatalError("Invest history fetch error")
        }
    }
    
    func prepareChart(with chart: PieChartView) {
        
        chartService.prepareForPieChart(pieChartView: chart)
    }
    
    func fetchDividend(with stockNo: String) {
        let stockDividend = repository.fetchStockDividend(with: stockNo)
        let cashDividend = repository.fetchCashDividend(with: stockNo)
        
        var all:[Dividend] = []
        for s in stockDividend {
            all.append(Dividend(stockNo: s.stockNo!, cash: 0, share: Int(s.amount), date: s.date))
        }
        for s in cashDividend {
            all.append(Dividend(stockNo: s.stockNo!, cash: Int(s.amount), share: 0, date: s.date))
        }
        allDividendsCombine.send(all)
    }
    func fetchDividendAndClassify() {
        let stockDividend = repository.fetchStockDividend()
        let cashDividend = repository.fetchCashDividend()
        var stockDividendMap:[String: Int] = [:]
        var cashDividendMap:[String: Int] = [:]
        var stockNos:[String] = []
        var dividends:[Dividend] = []
        

        for s in stockDividend {
            if let value = stockDividendMap[s.stockNo!] {
                stockDividendMap[s.stockNo!] = value+Int(s.amount)
            } else {
                stockDividendMap[s.stockNo!] = Int(s.amount)
            }
            if !stockNos.contains(s.stockNo!) {
                stockNos.append(s.stockNo!)
            }
        }
        for s in cashDividend {
            if let value = cashDividendMap[s.stockNo!] {
                cashDividendMap[s.stockNo!] = value+Int(s.amount)
            } else {
                cashDividendMap[s.stockNo!] = Int(s.amount)
            }
            if !stockNos.contains(s.stockNo!) {
                stockNos.append(s.stockNo!)
            }
        }
        for stockNo in stockNos {
            let cash = cashDividendMap.first(where: {$0.key==stockNo})?.value ?? 0
            let share = stockDividendMap.first(where: {$0.key==stockNo})?.value ?? 0
            let dividend = Dividend(stockNo: stockNo, cash: cash, share: share)
            dividends.append(dividend)
        }
        
        print(dividends)
        self.classifiedDividendCombine.send(dividends)
    }
}
struct Dividend {
    let stockNo: String
    let cash: Int
    let share: Int
    var date: Date? = nil
}
