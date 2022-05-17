//
//  AddHistoryViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import CoreData
import Foundation

class AddHistoryViewModel {
    var context: NSManagedObjectContext?
    var buyOrSellStatus: Int! = 0
    var date: Date! = Date()
    
    func saveNewRecord(stockNo: String, price: Float, amount: Int, reason: String) {
        guard let context = context else { return }

        let newInvestHistory = InvestHistory(context: context)
        newInvestHistory.stockNo = stockNo
        newInvestHistory.price = price
        newInvestHistory.amount = Int16(amount)
        newInvestHistory.date = date
        newInvestHistory.status = Int16(buyOrSellStatus)
        newInvestHistory.reason = reason
        
        do {
            try context.save()
        } catch {
            fatalError("\(error.localizedDescription)")
        }

    }
}
