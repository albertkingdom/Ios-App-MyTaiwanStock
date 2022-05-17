//
//  StatisticViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import CoreData
import Foundation
import Charts

class StatisticViewModel {
    var context: NSManagedObjectContext?
    var chartService: ChartService!
    var stockNoToAsset = Observable<[StockStatistic]>([])
    
    lazy var fetchedResultsController: NSFetchedResultsController<InvestHistory> = {
    
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)

        fetchRequest.sortDescriptors = [sortDescriptor]

        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
       
        
        return frc
    }()
    var isEmptyData = Observable<Bool>(nil)
    
    init() {
        //let savedStockPrice = OneDayStockInfo.priceList
        //self.chartService = ChartService()
    }
    
    func fetchData(to chart: PieChartView) {
        do {
            try fetchedResultsController.performFetch()
    
            guard let historyList = fetchedResultsController.fetchedObjects else {
                isEmptyData.value = true
                return
            }
            let savedStockPrice = OneDayStockInfo.priceList
            
            self.chartService = ChartService(historyList: historyList, stockPriceList: savedStockPrice)
            guard let stockNoToAsset = chartService.calculateStockNoToAsset() else {
                isEmptyData.value = true
                return
            }
            //print("stockNoToAsset \(stockNoToAsset)")
            self.stockNoToAsset.value = stockNoToAsset
            
            if stockNoToAsset.isEmpty {
                isEmptyData.value = true
            }
            prepareChart(with: chart)
        } catch {
            fatalError("Invest history fetch error")
        }
    }
    
    func prepareChart(with chart: PieChartView) {
        
        chartService.prepareForPieChart(pieChartView: chart)
    }
}
