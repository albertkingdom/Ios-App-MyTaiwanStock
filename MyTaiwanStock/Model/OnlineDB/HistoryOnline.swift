//
//  History.swift
//  MyTaiwanStock
//
//  Created by YKLin on 9/7/22.
//

import Foundation

struct HistoryOnline: Codable {
    var id: String = UUID().uuidString
    let price: Double
    let amount: Int
    let stockNo: String
    let time: UInt64
    let email: String
    var status: Int = 0 //0: buy, 1: sell
}
