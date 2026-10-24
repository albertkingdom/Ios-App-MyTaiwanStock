//
//  AddDividendViewModel.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/22/22.
//

import Foundation

class AddDividendViewModel {
    let repository = NetworkServiceImpl()
    init() {
        
    }
    func saveDividends(stockNo: String, cashAmount: Int?, stockAmount: Int?, date: Date) -> Bool {
        var hasValue = false
        if let cashAmount = cashAmount {
            repository.saveCashDividend(stockNo: stockNo, amount: cashAmount, date: date)
            hasValue = true
        }
        if let stockAmount = stockAmount {
            repository.saveStockDividend(stockNo: stockNo, amount: stockAmount, date: date)
            hasValue = true
        }
        return hasValue
    }
    func validateCashDividend(_ input: String?) -> Int? {
        guard let input = input, let value = Int(input), value > 0 else { return nil }
        return value
    }
    
    func validateStockDividend(_ input: String?) -> Int? {
        guard let input = input, let value = Int(input), value > 0 else { return nil }
        return value
    }
}
