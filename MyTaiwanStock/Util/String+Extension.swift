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
}
