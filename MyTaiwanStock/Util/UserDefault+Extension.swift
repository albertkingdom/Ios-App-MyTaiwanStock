//
//  UserDefault+Extension.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/31/22.
//

import Foundation

extension UserDefaults {
    static let userDefinedFeeInDollarsKey = "userDefinedFeeInDollars"
    static let userDefinedFeeDiscountKey = "userDefinedFeeDiscount"
    /// "discount" or "fixedAmount"; absent means the discount mode.
    static let feeModeKey = "feeMode"
    /// The fee discount as a number from 0.1 to 10, where 10 means no discount.
    static let feeDiscountKey = "feeDiscount"
    static let feeMinimumWholeLotKey = "feeMinimumWholeLot"
    static let feeMinimumOddLotKey = "feeMinimumOddLot"
    static let isFirstTimeAfterSignIn = "isFirstTimeAfterSignIn"
    static let menuIndex = "Menu Index"
    static let isFirstTimeOpenApp = "isFirstTimeOpenApp"
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if self.object(forKey: key) == nil {
            return defaultValue
        }
        return self.bool(forKey: key)
    }
}
