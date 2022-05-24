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
    var context: NSManagedObjectContext?
    var chartService: ChartService!
    var stockNoToAssetCombine = CurrentValueSubject<[StockStatistic],Never>([])
    
    lazy var fetchedResultsController: NSFetchedResultsController<InvestHistory> = {
    
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)

        fetchRequest.sortDescriptors = [sortDescriptor]

        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
       
        
        return frc
    }()
    var isLoading = PassthroughSubject<Bool, Never>()
    
    
    func fetchData(to chart: PieChartView) {
        do {
            try fetchedResultsController.performFetch()
    
            guard let historyList = fetchedResultsController.fetchedObjects else {
                isLoading.send(true)
                return
            }
            let savedStockPrice = OneDayStockInfo.priceList
            
            self.chartService = ChartService(historyList: historyList, stockPriceList: savedStockPrice)
            guard let stockNoToAsset = chartService.calculateStockNoToAsset() else {
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
}
