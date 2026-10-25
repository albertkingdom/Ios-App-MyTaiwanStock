//
//  FeeSettings.swift
//  MyTaiwanStock
//

import Foundation

/// The brokerage fee settings chosen in the settings screen.
struct FeeSettings: Equatable {
    /// The standard rate multiplied by a discount from 0.1 to 10, where 10 means no discount.
    static let noDiscount = Decimal(10)
    static let defaultWholeLotMinimumFee = 20
    static let defaultOddLotMinimumFee = 1

    var discount: Decimal
    var wholeLotMinimumFee: Int
    var oddLotMinimumFee: Int

    init(
        discount: Decimal = FeeSettings.noDiscount,
        wholeLotMinimumFee: Int = FeeSettings.defaultWholeLotMinimumFee,
        oddLotMinimumFee: Int = FeeSettings.defaultOddLotMinimumFee
    ) {
        self.discount = discount
        self.wholeLotMinimumFee = wholeLotMinimumFee
        self.oddLotMinimumFee = oddLotMinimumFee
    }

    /// Reads the settings without writing anything. Without a saved discount, the earlier choice, the
    /// position of the discount in a list that started at 1, is read as that position plus one; without
    /// either, there is no discount. A minimum fee that is not saved as a whole number in range is read as
    /// its default.
    static func current(userDefaults: UserDefaults = .standard) -> FeeSettings {
        FeeSettings(
            discount: storedDiscount(in: userDefaults),
            wholeLotMinimumFee: storedMinimumFee(
                forKey: UserDefaults.feeMinimumWholeLotKey, defaultFee: defaultWholeLotMinimumFee, in: userDefaults),
            oddLotMinimumFee: storedMinimumFee(
                forKey: UserDefaults.feeMinimumOddLotKey, defaultFee: defaultOddLotMinimumFee, in: userDefaults))
    }

    /// Writes the discount and both minimum fees together.
    static func save(_ settings: FeeSettings, userDefaults: UserDefaults = .standard) {
        userDefaults.set(NSDecimalNumber(decimal: settings.discount).doubleValue, forKey: UserDefaults.feeDiscountKey)
        userDefaults.set(settings.wholeLotMinimumFee, forKey: UserDefaults.feeMinimumWholeLotKey)
        userDefaults.set(settings.oddLotMinimumFee, forKey: UserDefaults.feeMinimumOddLotKey)
    }

    /// The line the settings screen shows, for example "2.8 折・最低 20 / 1 元" or "無折扣・最低 20 / 1 元".
    var summaryText: String {
        let discountText = discount == FeeSettings.noDiscount ? "無折扣" : "\(discount) 折"
        return "\(discountText)・最低 \(wholeLotMinimumFee) / \(oddLotMinimumFee) 元"
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

    /// Validates the three values of the settings page together. The error names the first invalid value in
    /// the order discount, whole-lot minimum fee, odd-lot minimum fee. Nothing is written here; see `save`.
    static func parse(
        discountText: String?, wholeLotMinimumText: String?, oddLotMinimumText: String?
    ) throws -> FeeSettings {
        let discount = try parseDiscount(discountText)
        guard let wholeLotMinimumFee = try? ValidInputService().validFeeOrTaxInput(wholeLotMinimumText) else {
            throw FeeSettingsError.invalidWholeLotMinimumFee
        }
        guard let oddLotMinimumFee = try? ValidInputService().validFeeOrTaxInput(oddLotMinimumText) else {
            throw FeeSettingsError.invalidOddLotMinimumFee
        }
        return FeeSettings(
            discount: discount, wholeLotMinimumFee: wholeLotMinimumFee, oddLotMinimumFee: oddLotMinimumFee)
    }

    private static let minimumDiscount = Decimal(string: "0.1")!

    private static func storedMinimumFee(forKey key: String, defaultFee: Int, in userDefaults: UserDefaults) -> Int {
        // `as? Int` alone would also take a Double such as 25.0 or a Bool, so check how the number was saved.
        guard let number = userDefaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(), !CFNumberIsFloatType(number),
              (0...Int(Int32.max)).contains(number.intValue)
        else {
            return defaultFee
        }
        return number.intValue
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
    case invalidWholeLotMinimumFee
    case invalidOddLotMinimumFee

    var errorDescription: String? {
        switch self {
        case .invalidDiscount:
            return "折數請輸入 0.1 到 10 的數字，最多兩位小數"
        case .invalidWholeLotMinimumFee:
            return "整股最低手續費請輸入 0 到 2147483647 的整數"
        case .invalidOddLotMinimumFee:
            return "零股最低手續費請輸入 0 到 2147483647 的整數"
        }
    }
}
