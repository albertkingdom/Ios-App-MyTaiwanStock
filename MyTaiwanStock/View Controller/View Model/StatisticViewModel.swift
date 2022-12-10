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
            print("stockNOs \(stockNos)")
            
            let stockNoObjects = repository.fetchStockPriceFromDB(with: stockNos)
            print("stockNoObjects \(stockNoObjects)")
            
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
}
