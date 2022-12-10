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

    var onlineDBService: OnlineDBService?
    let repository = RepositoryImpl()
    
    init(context: NSManagedObjectContext?) {
        self.context = context

        self.onlineDBService = OnlineDBService(context: context)

    }

    
    func saveNewInvestRecord(stockNo: String, price: Float, amount: Int, reason: String) {
        repository.saveNewRecord(stockNo: stockNo,
                                 price: price,
                                 amount: amount,
                                 reason: reason,
                                 buyOrSellStatus: buyOrSellStatus,
                                 date: date)
    }
}
