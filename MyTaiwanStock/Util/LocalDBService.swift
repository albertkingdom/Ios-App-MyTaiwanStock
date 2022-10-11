//
//  LocalDBService.swift
//  MyTaiwanStock
//
//  Created by YKLin on 10/8/22.
//

import Foundation
import CoreData
import UIKit

class LocalDBService {
    
    var context: NSManagedObjectContext?
    init(context: NSManagedObjectContext?) {
        self.context = context
    }
    init() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.context = appDelegate.persistentContainer.viewContext
    }
    // MARK: Core Data - fetch list
    func fetchAllListFromDB() -> [List]{
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        var lists: [List] = []
        do {
            guard let result = try context?.fetch(fetchRequest) else { return [List]() }
            //print("lists \(result)")

            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    
    // MARK: Core Data - fetch history
    func fetchHistoryFromDB(with stockNo: String) -> [InvestHistory]{
       
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo == %@", stockNo)
        var lists: [InvestHistory] = []
        do {
            guard let result = try context?.fetch(fetchRequest) else { return []}
            //print("lists \(result)")
            
            lists = result
        
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    
    /// update currentPrice property of stockNo
    func updateStockNoInDBwithPrice(stockNos: [String], cellViewModels: [StockCellViewModel]) {

        let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo IN %@", stockNos)
        do {
            guard let stocks = try context?.fetch(fetchRequest) else {return}
            
            print("updateStockNoFromDBwithPrice stocks \(stocks), stocks count \(stocks.count)")
            
            for stock in stocks {
                if let price = cellViewModels.first(where: {$0.stockNo==stock.stockNo})?.stockPrice,
                let priceDouble = Double(price) {
                    
                    stock.currentPrice = priceDouble
                }
                
            }
            saveContext()
        
        } catch let error {
            print(error.localizedDescription)
        }
        
    }
    
    func fetchStockPriceFromDB(with stockNos: [String]) -> [StockNo]{
        let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo IN %@", stockNos)
        do {
            guard let stocks = try context?.fetch(fetchRequest) else {return []}
            
            print("fetchStockPriceFromDB stocks \(stocks), stocks count \(stocks.count)")
            
            return stocks
        
        } catch let error {
            print(error.localizedDescription)
        }
        return []
    }
    // MARK: Core Data - save list
    func saveNewListToDB(listName: String) -> List? {
        
        let newList = List(context: context!)
        newList.name = listName
        
        saveContext()
        return newList
    }
    // MARK: Core Data - save stockNo
    func saveNewStockNumberToDB(stockNumber: String, currentFollowingList: List) {
 
        guard let context = self.context else { return }

        let newStockNo = StockNo(context: context)
        newStockNo.stockNo = stockNumber
        newStockNo.ofList = currentFollowingList // set the relationship between list and stockNo

        saveContext()
    }
    // MARK: Core Data - save new record
    func saveNewRecord(stockNo: String, price: Float, amount: Int, reason: String, buyOrSellStatus: Int, date: Date) {
        guard let context = context else { return }

        let newInvestHistory = InvestHistory(context: context)
        newInvestHistory.stockNo = stockNo
        newInvestHistory.price = price
        newInvestHistory.amount = Int16(amount)
        newInvestHistory.date = date
        newInvestHistory.status = Int16(buyOrSellStatus)
        newInvestHistory.reason = reason
        
        saveContext()

    }

    // MARK: Core Data - delete
    func deleteStockNumberInDB(stockNoObject: StockNo) {
        context?.delete(stockNoObject)
        
        let result = checkIfRemainingStockNoObject(with: stockNoObject.stockNo!)
        
        if !result {
            deleteHistory(with: stockNoObject.stockNo!)
        }
        // TODO: show the UIAlert
        saveContext()

    }
    func deleteHistoryInDB(historyObject: InvestHistory) {
        context?.delete(historyObject)
        saveContext()
    }
    private func checkIfRemainingStockNoObject(with stockNo: String) -> Bool {
        let fetchStockRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchStockRequest.predicate = predicate
        
        if let stockNoObjects = try? context?.fetch(fetchStockRequest) {
  
            if stockNoObjects.isEmpty {
                // there's no stockNo object with same stockNo
                return false
            }
            
        }
        return true
    }
    private func deleteHistory(with stockNo: String) {
        // fetch history with stockNo, then delete them
        let fetchHistoryRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchHistoryRequest.predicate = predicate
        
        if let historyObjects = try? context?.fetch(fetchHistoryRequest) {
            //print("historyObjects \(historyObjects)")
            
            for history in historyObjects {
                context?.delete(history)
            }
            saveContext()
        }
    }
    func deleteListFromDB(list: List) {
        context?.delete(list)
        saveContext()
    }
    
    func save() {
        do {
            try context?.save()
        } catch {
            print("error, \(error.localizedDescription)")
        }
    }
    func saveContext() {
        guard let context = context else {
            return
        }
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch let error as NSError {
            print("Error: \(error), \(error.userInfo)")
        }
    }
    
    struct StockNoToPrice {
        let stockNo: String
        let price: Double
    }
}
