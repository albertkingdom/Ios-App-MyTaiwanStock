//
//  ValidInputService.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/26/22.
//

import Foundation

struct ValidInputService {
    func validStockPriceInput(_ price: String?) throws -> Float {
        guard let priceText = price,
              let priceInt = Float(priceText)
        else {
            throw ValidationError.invalidFloat
        }
        return priceInt
    }
    
    func validStockAmountInput(_ amount: String?) throws -> Int {
        guard let amountText = amount,
              let amountInt = Int(amountText)
        else {
            throw ValidationError.invalidInt
        }
        
        return amountInt
    }
    
    func validStockNo(_ stockNo: String?) throws -> String {
        guard let stockNoText = stockNo,
              stockNoList.contains(where: { string in string.contains(stockNoText) })
        else {
            throw ValidationError.invalidStockNo
        }
        
        return stockNoText
    }
    
}

enum ValidationError: LocalizedError {
    case invalidFloat
    case invalidInt
    case invalidStockNo
    
    var errorDescription: String? {
        switch self {
        case .invalidFloat:
            return "請輸入正確交易價位數字"
        case .invalidInt:
            return "請輸入正確交易量股數"
        case .invalidStockNo:
            return "請輸入正確股票代號"
        }
  
    }
}
