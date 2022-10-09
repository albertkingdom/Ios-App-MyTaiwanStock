//
//  LocalDBService.swift
//  MyTaiwanStock
//
//  Created by YKLin on 10/8/22.
//

import Foundation
import CoreData

class LocalDBService {
    var context: NSManagedObjectContext?
    init(context: NSManagedObjectContext?) {
        self.context = context
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
    func fetchDB(stockNo: String) -> [InvestHistory]{
       
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
    // MARK: Core Data - save list
    func saveNewListToDB(listName: String) -> List? {
        
        let newList = List(context: context!)
        newList.name = listName
        
        save()
        return newList
    }
    // MARK: Core Data - save stockNo
    func saveNewStockNumberToDB(stockNumber: String, currentFollowingList: List) {
 
        guard let context = self.context else { return }

        let newStockNo = StockNo(context: context)
        newStockNo.stockNo = stockNumber
        newStockNo.ofList = currentFollowingList // set the relationship between list and stockNo

        save()
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
        
        save()

    }

    // MARK: Core Data - delete
    func deleteStockNumberInDB(stockNoObject: StockNo) {
        context?.delete(stockNoObject)
        
        let result = checkIfRemainingStockNoObject(with: stockNoObject.stockNo!)
        
        if !result {
            deleteHistory(with: stockNoObject.stockNo!)
        }
        // TODO: show the UIAlert
        save()

    }
    func deleteHistoryInDB(historyObject: InvestHistory) {
        context?.delete(historyObject)
        save()
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
            save()
        }
    }
    func deleteListFromDB(list: List) {
        context?.delete(list)
        save()
    }
    
    func save() {
        do {
            try context?.save()
        } catch {
            print("error, \(error.localizedDescription)")
        }
    }
}
