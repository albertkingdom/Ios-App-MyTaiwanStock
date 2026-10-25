//
//  String+Extension.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/10/31.
//

import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    // 如果需要帶參數
    func localized(with arguments: [CVarArg]) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }

    /// Reads a number from a TWSE table cell. TWSE writes values of 1,000 and above with a
    /// thousands separator ("2,565.00") and "--" when there is no value (for example, no trades that day).
    var twseNumber: Double? {
        guard let number = Double(replacingOccurrences(of: ",", with: "")), number.isFinite else { return nil }
        return number
    }
}
