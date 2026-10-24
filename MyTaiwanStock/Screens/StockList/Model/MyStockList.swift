//
//  MyStockList.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/4.
//

import Foundation

struct StockList: Codable {
    var stockNo: String
}
class MyStockList {
    
    static let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let archiveURL = documentDirectory.appendingPathComponent("mystockList").appendingPathExtension("plist")
    
    static func saveToDisk(stockList: [StockList]) {
        let propertyListEncoder = PropertyListEncoder()
        let encodedList = try? propertyListEncoder.encode(stockList)
        
        try? encodedList?.write(to: archiveURL, options: .noFileProtection)
    }
    
    static func loadFromDisk() -> [StockList] {
        let propertyListDecoder = PropertyListDecoder()
        if let retrievedListData = try? Data(contentsOf: archiveURL), let decodedList = try? propertyListDecoder.decode([StockList].self, from: retrievedListData) {
            
                //6print("loadFromDisk(): \(decodedList)")
            return decodedList
        } else {
            return defaultStockList()
        }
    }
    
    static func defaultStockList() -> [StockList] {
        return [StockList(stockNo: "0050"), StockList(stockNo: "2330")]
    }
}
