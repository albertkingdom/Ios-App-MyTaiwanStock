//
//  AddDividendViewModel.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/22/22.
//

import Foundation

class AddDividendViewModel {
    let repository = RepositoryImpl()
    init() {
        
    }
    func saveStockDividend(stockNo: String, amount: Int, date: Date) {
        repository.saveStockDividend(stockNo: stockNo, amount: amount, date: date)
    }
    func saveCashDividend(stockNo: String, amount: Int, date: Date) {
        repository.saveCashDividend(stockNo: stockNo, amount: amount, date: date)
    }
}
