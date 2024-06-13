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
    var buyOrSellStatus: Int! = 0 // 0: buy, 1: sell
    var date: Date! = Date()
    var memo = ""
    var onlineDBService: OnlineDBService?
    let repository = NetworkServiceImpl()
    private var feeAmount: Float = 0 {
        didSet {
            logger.debug("feeAmount: \(self.feeAmount)")
            updateFeeAmount?(feeAmount)
        }
    }
    private var taxAmount: Float = 0
    private var feeMultipler: Float = 0.6
    var updateFeeAmount: ((Float)->Void)?
    var revenue: Float = 0
    
    init(context: NSManagedObjectContext?) {
        self.context = context

        self.onlineDBService = OnlineDBService(context: context)
    }
    
    init() {
        self.onlineDBService = OnlineDBService()
    }
    
    func saveNewInvestRecord(stockNo: String, price: Float, amount: Int, reason: String) {
        repository.saveNewRecord(
            stockNo: stockNo,
            price: price,
            amount: amount,
            reason: memo,
            buyOrSellStatus: buyOrSellStatus,
            date: date
        )
    }
    
    func calculateFeeAndTax(price: Float, amount: Float, buyOrSell: Int) {
        let total = price*amount*feeMultipler*0.001425
        feeAmount = total<20 ? 20 : total
        if buyOrSell==1 {
            taxAmount = price*amount*0.003
        }
    }
    
    func updateFeeMultiplier(multiplier: Float) {
        feeMultipler = multiplier
    }
    func updateFee(_ value: Float) {
        feeAmount = value
    }
    
}
