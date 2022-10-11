//
//  StockViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//

import Foundation

struct StockCellViewModel {
    let stockNo: String
    let stockShortName: String
    let stockPrice: String
    let stockPriceDiff: String
    
    init(stock: OneDayStockInfoDetail) {
        self.stockNo = stock.stockNo
        self.stockShortName = stock.shortName
       
        var price = ""
        
        if let currentPrice = Float(stock.current){
            price = String(format: "%.2f", currentPrice)
        } else {
            if let yesterDayPrice = Float(stock.yesterDayPrice) {
                price = String(format: "%.2f", yesterDayPrice)
            }
        }
        stockPrice = price

        
        if let currentPrice = Float(stock.current), let openPrice = Float(stock.open) {
            let diff = currentPrice - openPrice
            stockPriceDiff = String(format: "%.2f", diff)
        } else {
            stockPriceDiff = "-"
        }
    }
}
