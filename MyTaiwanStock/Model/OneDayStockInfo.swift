//
//  OneDayStockInfo.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//
import Combine
import Foundation

struct OneDayStockInfo: Codable {
    var msgArray: [OneDayStockInfoDetail]
}

struct OneDayStockInfoDetail: Codable {
    var stockNo: String //代號
    var open: String //開盤
    var low: String //最低
    var high: String //最高
    var fullName: String //公司全名
    var current: String //當盤成交價
    var shortName: String //公司簡稱
    var yesterDayPrice: String //昨日收盤
    var time: String //報價時間
    
    enum CodingKeys: String, CodingKey {
        case stockNo = "c"
        case open = "o"
        case low = "l"
        case high = "h"
        case fullName = "nf"
        case current = "z"
        case shortName = "n"
        case yesterDayPrice = "y"
        case time = "t"
    }
}
