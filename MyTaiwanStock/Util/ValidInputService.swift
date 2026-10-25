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
    
    /// A record stores its share count in 16 bits, so more than 32767 shares cannot be saved.
    func validStockAmountInput(_ amount: String?) throws -> Int {
        guard let amountText = amount,
              let amountInt = Int(amountText),
              amountInt > 0,
              amountInt <= Int(Int16.max)
        else {
            throw ValidationError.invalidAmount
        }
        
        return amountInt
    }
    
    func validStockNo(_ stockNo: String?) throws -> String {
        // Exact match on the code; a partial code such as "23" is not a stock number.
        // Validation is driven from UI input, so this always runs on the main thread.
        guard let stockNoText = stockNo,
              MainActor.assumeIsolated({ StockListRepository.shared.contains(code: stockNoText) })
        else {
            throw ValidationError.invalidStockNo
        }
        
        return stockNoText
    }
    
    /// The fee or the tax typed for a record: a whole number of dollars from 0 to 2147483647.
    func validFeeOrTaxInput(_ text: String?) throws -> Int {
        guard let text = text?.trimmingCharacters(in: .whitespaces),
              let value = Int(text),
              (0...Int(Int32.max)).contains(value)
        else {
            throw ValidationError.invalidFeeOrTax
        }
        return value
    }
    
}

enum ValidationError: LocalizedError {
    case invalidPrice
    case invalidAmount
    case invalidStockNo
    case invalidFeeOrTax
    
    var errorDescription: String? {
        switch self {
        case .invalidPrice:
            return "請輸入正確交易價位數字"
        case .invalidAmount:
            return "請輸入正確交易量股數（1 到 32767）"
        case .invalidStockNo:
            return "請輸入正確股票代號"
        case .invalidFeeOrTax:
            return "手續費與稅請輸入 0 以上的整數"
        }
  
    }
}
