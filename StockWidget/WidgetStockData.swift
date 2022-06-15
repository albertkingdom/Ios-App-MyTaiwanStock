//
//  WidgetStockData.swift
//  StockWidgetExtension
//
//  Created by 林煜凱 on 6/9/22.
//

import Foundation

struct WidgetStockData: Identifiable {
    let id = UUID()
    var stockNo: String
    var current: String //當盤成交價
    var shortName: String //公司簡稱
    var yesterDayPrice: String //昨日收盤
    var diff: String{
        if current != "-", let currentFloat = Float(current), let yesterDayFloat = Float(yesterDayPrice) {
            return String(format: "%.2f", currentFloat - yesterDayFloat)
        }
        return "-"
    }
    
}
