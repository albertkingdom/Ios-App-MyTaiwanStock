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
       
        
       
        if let currentPrice = Float(stock.current) {
            stockPrice = String(format: "%.2f", currentPrice)
        } else {
            stockPrice = String(format: "%.2f", stock.yesterDayPrice)
        }
        
        
        if let currentPrice = Float(stock.current), let openPrice = Float(stock.open) {
            let diff = currentPrice - openPrice
            stockPriceDiff = String(format: "%.2f", diff)
        } else {
            stockPriceDiff = "-"
        }
    }
}
