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
              let priceInt = Float(priceText),
              priceInt > 0
        else {
            throw ValidationError.invalidPrice
        }
        return priceInt
    }
    
    func validStockAmountInput(_ amount: String?) throws -> Int {
        guard let amountText = amount,
              let amountInt = Int(amountText),
              amountInt > 0
        else {
            throw ValidationError.invalidAmount
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
    case invalidPrice
    case invalidAmount
    case invalidStockNo
    
    var errorDescription: String? {
        switch self {
        case .invalidPrice:
            return "請輸入正確交易價位數字"
        case .invalidAmount:
            return "請輸入正確交易量股數"
        case .invalidStockNo:
            return "請輸入正確股票代號"
        }
  
    }
}
