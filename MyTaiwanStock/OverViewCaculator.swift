//
//  OverView.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/11/24.
//

import Foundation

class OverViewCalculator {
    var amount: Int = 0
    var stockPrice: Float?
    var historys: [HistoryCellModel]
    
    init(historys: [HistoryCellModel], stockPrice: Float?) {
        self.stockPrice = stockPrice
        self.historys = historys
        self.amount = totalAmount(with: historys)
        
    }
    
    private func totalAmount(with historys: [HistoryCellModel]) -> Int {
        return historys.map {
            print($0.amountString)
            guard let amountInt = Int($0.amountString) else { return 0 }
            print(amountInt)
            return amountInt
        }.reduce(0) { partialResult, item in
            partialResult+item
        }
    }
    
    func averageBuyPrice() -> Float {
        let buyTotalValue = self.historys.filter {$0.status==0}.map { history -> Float in
            guard let amountFloat = Float(history.amountString),
                  let priceFloat = Float(history.priceString)
            else { return Float(0) }
            return amountFloat*priceFloat
        }.reduce(0) {partialResult, item in
            partialResult+item
        }        
        return buyTotalValue/Float(amount)
    }
    
    func averageSellPrice() -> Float {
        var sellStockAmount = Float(0)
        let sellTotalValue = historys.filter {$0.status==1}.map { history -> Float in
            
            guard let amountFloat = Float(history.amountString),
                  let priceFloat = Float(history.priceString)
            else { return Float(0) }
            
            sellStockAmount+=amountFloat

            return amountFloat*priceFloat
        }.reduce(0) {partialResult, item in
            partialResult+item
        }
        let localAvgSellPrice = sellTotalValue/Float(sellStockAmount)
        return localAvgSellPrice
    }
    
    func totalAsset() -> Float? {
        if let stockPriceFloat = stockPrice {
            let assetFloat = Float(amount)*stockPriceFloat
            return assetFloat
        }
        return nil
    }
}
