//
//  StockViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//

import Foundation

struct StockCellViewModel: Hashable {
    let stockNo: String
    let stockShortName: String
    let stockPrice: String
    let stockPriceDiff: String
    let stockPriceDiffPercent: String
    let time: String
    var priceDiffFormat: PriceDiffFormat = .Digit
    
    enum PriceDiffFormat {
        case Percentage
        case Digit
    }
    
    init(stockNo: String) {
        self.stockNo = stockNo
        self.stockShortName = "-"
        self.stockPrice = "-"
        self.stockPriceDiff = "-"
        self.stockPriceDiffPercent = "-"
        self.time = "-"
    }
    
    init(stock: OneDayStockInfoDetail, priceDiffInPercentage: PriceDiffFormat) {
        self.stockNo = stock.stockNo
        self.stockShortName = stock.shortName
        self.priceDiffFormat = priceDiffInPercentage
        var price = ""
        
        if let currentPrice = Float(stock.current){
            price = String(format: "%.2f", currentPrice)
        } else {
            if let yesterDayPrice = Float(stock.yesterDayPrice) {
                price = String(format: "%.2f", yesterDayPrice)
            }
        }
        stockPrice = price

        
        if let currentPrice = Float(stock.current), let yesterDayPrice = Float(stock.yesterDayPrice), let openPrice = Float(stock.open) {
            let diff = currentPrice - yesterDayPrice
            var diffPercent = (currentPrice - openPrice)/openPrice
            if stock.time == "13:30:00" {
                diffPercent = (currentPrice - yesterDayPrice)/yesterDayPrice
            }
            stockPriceDiff = String(format: "%.2f", diff)
            
            stockPriceDiffPercent = String(format: "%.3f", diffPercent) + "%"
        } else {
            stockPriceDiff = "-"
            stockPriceDiffPercent = "-"
        }
        
        self.time = stock.time
    }
}
