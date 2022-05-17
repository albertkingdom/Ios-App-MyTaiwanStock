//
//  HistoryCellViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//

import Foundation

struct HistoryCellViewModel {
    var status: Int16 {
        return historyData.status
    } // 0: buy, 1: sell
    var dateString: String {
        return dateFormat(date: historyData.date!)
    }
    var priceString: String {
        return String(historyData.price)
    }
    var amountString: String {
        return String(historyData.amount)
    }
    var revenueString: String {
        let revenueInString = calcRevenue(price: historyData.price)
        return Int(self.status) == 0 ? "\(revenueInString) %" : "N/A"
    }
    var revenueFloat: Float {
        
        return Float(revenueString) ?? 0
    }
    var historyData: InvestHistory
    var currentStockPriceString: String
    
    init(historyData: InvestHistory, currentStockPrice: String) {
        self.historyData = historyData
        self.currentStockPriceString = currentStockPrice
        
        
    }
    
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy\nMM-dd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }
    
    func calcRevenue(price: Float) -> String {
        var revenueStr: String! = "-"
        if currentStockPriceString != "-" {
            if let StockPriceFloat = Float(currentStockPriceString) {
                let result = (StockPriceFloat - price) / price * 100
                revenueStr = String(format:"%.2f", result)
            }
        }
        return revenueStr
    }
}
