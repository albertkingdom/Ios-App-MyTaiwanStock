//
//  FeeSettings.swift
//  MyTaiwanStock
//

import Foundation

/// How the brokerage fee is charged, as chosen in the settings screen.
struct FeeSettings: Equatable {
    enum Mode: Equatable {
        /// The standard rate multiplied by a discount from 0.1 to 10, where 10 means no discount.
        case discount(Decimal)
        /// A fixed amount in whole dollars that replaces the formula.
        case fixedAmount(Int)
    }

    static let noDiscount = Decimal(10)

    var mode: Mode

    /// Reads the settings without writing anything. Without a saved mode the mode is the discount mode, so
    /// a fixed amount saved before modes existed is not applied to every trade. Without a saved discount,
    /// the earlier choice, the position of the discount in a list that started at 1, is read as that
    /// position plus one; without either, there is no discount.
    static func current(userDefaults: UserDefaults = .standard) -> FeeSettings {
        if userDefaults.string(forKey: UserDefaults.feeModeKey) == "fixedAmount" {
            let amount = userDefaults.double(forKey: UserDefaults.userDefinedFeeInDollarsKey)
            return FeeSettings(mode: .fixedAmount(max(0, Int(amount.rounded(.down)))))
        }
        return FeeSettings(mode: .discount(storedDiscount(in: userDefaults)))
    }

    private static func storedDiscount(in userDefaults: UserDefaults) -> Decimal {
        if let saved = userDefaults.object(forKey: UserDefaults.feeDiscountKey) as? Double,
           let discount = Decimal(string: String(saved)), (Decimal(string: "0.1")!...noDiscount).contains(discount) {
            return discount
        }
        if let position = userDefaults.object(forKey: UserDefaults.userDefinedFeeDiscountKey) as? Int {
            return Decimal(min(max(position + 1, 1), 10))
        }
        return noDiscount
    }
}
