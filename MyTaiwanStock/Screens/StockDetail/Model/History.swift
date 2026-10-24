//
//  History.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/6.
//

import Foundation

struct History: Codable {
    var id: Int
    var stockNo: String
    var date: Date
    var price: Float
    var amount: Int
    var status: Int //0: buy, 1: sell
}


class HistoryList {
    static var historyList: [History] = []
    
    static let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let archieveURL = documentDirectory.appendingPathComponent("myStockHistory").appendingPathExtension("plist")
    
    static func saveToDisk(newHistory: History) {
        let newHistoryRecord = newHistory
        historyList.append(newHistoryRecord)
        
        let propertyListEncoder = PropertyListEncoder()
        let encodedList = try? propertyListEncoder.encode(historyList)
  
        try? encodedList?.write(to: archieveURL, options: .noFileProtection)
    }
    
    static func loadFromDisk() -> [History] {
        let propertyListDecoder = PropertyListDecoder()
        if let retrievedListData = try? Data(contentsOf: archieveURL), let decodedList = try? propertyListDecoder.decode([History].self, from: retrievedListData) {
            
            //print("loadFromDisk(): \(decodedList)")
            historyList = decodedList
            return decodedList
        } else {
            historyList = defaultHistory
            return defaultHistory
        }
    }
    
    static let defaultHistory = [
        History(id: 1, stockNo: "0050", date: Date(), price: 100.0, amount: 999, status: 1),
        History(id: 2, stockNo: "0050", date: Date(), price: 100.0, amount: 999, status: 0),
        History(id: 3, stockNo: "0050", date: Date(), price: 100.0, amount: 999, status: 1),
        History(id: 4, stockNo: "0050", date: Date(), price: 100.0, amount: 999, status: 0),
        History(id: 5, stockNo: "0050", date: Date(), price: 100.0, amount: 999, status: 0),
    ]
    
    
    static func createId(historyList: [History]) -> Int {
        guard let lastId = historyList.last?.id else {
            return 0
        }
        let newId = lastId + 1
        return newId
    }
}
