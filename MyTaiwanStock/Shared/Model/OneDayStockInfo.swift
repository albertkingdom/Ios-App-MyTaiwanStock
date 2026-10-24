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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // stockNo 是必要欄位，如果沒有就應該拋出錯誤
        stockNo = try container.decode(String.self, forKey: .stockNo)
        
        // 其他欄位使用 decodeIfPresent，解析失敗時使用預設值
        open = try container.decodeIfPresent(String.self, forKey: .open) ?? "0"
        low = try container.decodeIfPresent(String.self, forKey: .low) ?? "0"
        high = try container.decodeIfPresent(String.self, forKey: .high) ?? "0"
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        current = try container.decodeIfPresent(String.self, forKey: .current) ?? "0"
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName) ?? ""
        yesterDayPrice = try container.decodeIfPresent(String.self, forKey: .yesterDayPrice) ?? "0"
        time = try container.decodeIfPresent(String.self, forKey: .time) ?? ""
    }
}
