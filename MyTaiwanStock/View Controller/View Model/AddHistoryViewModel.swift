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
    var localDB: LocalDBService!
    var onlineDBService: OnlineDBService?
    init(context: NSManagedObjectContext?) {
        self.context = context

        self.onlineDBService = OnlineDBService(context: context)
        localDB = LocalDBService(context: context)
    }
    func saveNewRecord(stockNo: String, price: Float, amount: Int, reason: String) {

        localDB.saveNewRecord(stockNo: stockNo, price: price, amount: amount, reason: reason, buyOrSellStatus: buyOrSellStatus, date: date)
    }
    func uploadHistoryToOnlineDB(stockNo: String, price: Float, amount: Int) {
        let timeInMillis = UInt64(date.timeIntervalSince1970*1000)
        onlineDBService?.uploadHistoryToOnlineDB(stockNo: stockNo, price: price, amount: amount, time: timeInMillis, status: buyOrSellStatus)
    }
}
