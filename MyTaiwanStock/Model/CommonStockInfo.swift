//
//  CommonStockInfo.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/4/3.
//

import Foundation

struct CommonStockInfo: Identifiable, Codable {
    var id = UUID()
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
    
    enum CodingKeys: String, CodingKey {
        case stockNo
       
        case current
        case shortName
        case yesterDayPrice
        case diff
    }
    init(stockNo: String, current: String, shortName:String,  yesterDayPrice: String) {
        self.stockNo = stockNo
        self.current = current
        self.shortName = shortName
        self.yesterDayPrice = yesterDayPrice
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        stockNo = try values.decode(String.self, forKey: .stockNo)
        current = try values.decode(String.self, forKey: .current)
        shortName = try values.decode(String.self, forKey: .shortName)
        yesterDayPrice = try values.decode(String.self, forKey: .yesterDayPrice)
        //diff = try values.decode(String.self, forKey: .diff)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stockNo, forKey: .stockNo)
        try container.encode(current, forKey: .current)
        try container.encode(shortName, forKey: .shortName)
        try container.encode(yesterDayPrice, forKey: .yesterDayPrice)
        
        try container.encode(diff, forKey: .diff)
    }
}
