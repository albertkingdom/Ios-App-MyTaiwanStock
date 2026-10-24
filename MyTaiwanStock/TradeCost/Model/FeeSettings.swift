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
    static let defaultWholeLotMinimumFee = 20
    static let defaultOddLotMinimumFee = 1

    var mode: Mode
    var discount: Decimal
    var wholeLotMinimumFee: Int
    var oddLotMinimumFee: Int

    init(
        mode: Mode,
        wholeLotMinimumFee: Int = FeeSettings.defaultWholeLotMinimumFee,
        oddLotMinimumFee: Int = FeeSettings.defaultOddLotMinimumFee
    ) {
        let discount: Decimal
        if case .discount(let value) = mode {
            discount = value
        } else {
            discount = FeeSettings.noDiscount
        }
        self.init(
            mode: mode, discount: discount, wholeLotMinimumFee: wholeLotMinimumFee, oddLotMinimumFee: oddLotMinimumFee)
    }

    private init(mode: Mode, discount: Decimal, wholeLotMinimumFee: Int, oddLotMinimumFee: Int) {
        self.mode = mode
        self.discount = discount
        self.wholeLotMinimumFee = wholeLotMinimumFee
        self.oddLotMinimumFee = oddLotMinimumFee
    }

    /// Reads the settings without writing anything. Without a saved mode the mode is the discount mode, so
    /// a fixed amount saved before modes existed is not applied to every trade. Without a saved discount,
    /// the earlier choice, the position of the discount in a list that started at 1, is read as that
    /// position plus one; without either, there is no discount. A minimum fee that is not saved as a whole
    /// number in range is read as its default.
    static func current(userDefaults: UserDefaults = .standard) -> FeeSettings {
        let discount = storedDiscount(in: userDefaults)
        let mode: Mode = usesFixedAmount(userDefaults: userDefaults)
            ? .fixedAmount(currentFixedAmount(userDefaults: userDefaults))
            : .discount(discount)
        return FeeSettings(
            mode: mode, discount: discount,
            wholeLotMinimumFee: storedMinimumFee(
                forKey: UserDefaults.feeMinimumWholeLotKey, defaultFee: defaultWholeLotMinimumFee, in: userDefaults),
            oddLotMinimumFee: storedMinimumFee(
                forKey: UserDefaults.feeMinimumOddLotKey, defaultFee: defaultOddLotMinimumFee, in: userDefaults))
    }

    // MARK: reading the parts, for the settings screen that shows both whichever mode is active

    static func usesFixedAmount(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.string(forKey: UserDefaults.feeModeKey) == "fixedAmount"
    }

    static func currentDiscount(userDefaults: UserDefaults = .standard) -> Decimal {
        storedDiscount(in: userDefaults)
    }

    /// The earlier settings screen saved whatever number was typed, so a stored value that is not a usable
    /// amount counts as 0, and one that is too large as the largest amount a record can hold.
    static func currentFixedAmount(userDefaults: UserDefaults = .standard) -> Int {
        let stored = userDefaults.double(forKey: UserDefaults.userDefinedFeeInDollarsKey)
        guard stored.isFinite, stored > 0 else { return 0 }
        return Int(min(stored.rounded(.down), Double(Int32.max)))
    }

    // MARK: writing

    static func saveMode(fixedAmount: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(fixedAmount ? "fixedAmount" : "discount", forKey: UserDefaults.feeModeKey)
    }

    static func saveDiscount(_ discount: Decimal, userDefaults: UserDefaults = .standard) {
        userDefaults.set(NSDecimalNumber(decimal: discount).doubleValue, forKey: UserDefaults.feeDiscountKey)
    }

    static func saveFixedAmount(_ amount: Int, userDefaults: UserDefaults = .standard) {
        userDefaults.set(Double(max(0, amount)), forKey: UserDefaults.userDefinedFeeInDollarsKey)
    }

    /// A discount typed in the settings screen: a plain number from 0.1 to 10 with at most two decimals.
    static func parseDiscount(_ text: String?) throws -> Decimal {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
              text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              text.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: text),
              (minimumDiscount...noDiscount).contains(value)
        else { throw FeeSettingsError.invalidDiscount }
        var hundredths = value * 100
        var whole = Decimal()
        NSDecimalRound(&whole, &hundredths, 0, .down)
        guard whole == value * 100 else { throw FeeSettingsError.invalidDiscount }
        return value
    }

    private static let minimumDiscount = Decimal(string: "0.1")!

    private static func storedMinimumFee(forKey key: String, defaultFee: Int, in userDefaults: UserDefaults) -> Int {
        guard let saved = userDefaults.object(forKey: key) as? Int, (0...Int(Int32.max)).contains(saved) else {
            return defaultFee
        }
        return saved
    }

    private static func storedDiscount(in userDefaults: UserDefaults) -> Decimal {
        if let saved = userDefaults.object(forKey: UserDefaults.feeDiscountKey) as? Double,
           let discount = Decimal(string: String(saved)), (minimumDiscount...noDiscount).contains(discount) {
            return discount
        }
        if let position = userDefaults.object(forKey: UserDefaults.userDefinedFeeDiscountKey) as? Int {
            return Decimal(min(max(position + 1, 1), 10))
        }
        return noDiscount
    }
}

enum FeeSettingsError: LocalizedError {
    case invalidDiscount

    var errorDescription: String? { "折數請輸入 0.1 到 10 的數字，最多兩位小數" }
}
