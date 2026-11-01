//
//  FeeCalculator.swift
//  MyTaiwanStock
//

import Foundation

/// The securities transaction tax category of a sell.
enum TaxCategory: CaseIterable, Equatable {
    case stock
    case dayTrade
    case etf
    case exempt

    var rate: Decimal {
        switch self {
        case .stock: return Decimal(string: "0.003")!
        case .dayTrade: return Decimal(string: "0.0015")!
        case .etf: return Decimal(string: "0.001")!
        case .exempt: return 0
        }
    }
}

struct FeeAndTax: Equatable {
    /// Whole dollars.
    let fee: Int
    let tax: Int
}

/// The brokerage fee and the transaction tax of one trade, in decimals and rounded down to whole dollars.
enum FeeCalculator {
    static let standardFeeRate = Decimal(string: "0.001425")!
    /// A trade of this many shares or more is charged the whole-lot minimum, even when it is not a multiple
    /// of it: the broker would split such a trade into a whole lot and an odd lot, which is not modeled.
    static let wholeLotShares = 1000

    /// A record stores its fee and its tax in 32 bits.
    static let largestAmount = Decimal(Int32.max)

    /// Nil when the price is not greater than 0, there is less than one share, or the fee or the tax would
    /// not fit in a record.
    static func calculate(
        price: Decimal, shares: Int, side: TradeSide, settings: FeeSettings, taxCategory: TaxCategory
    ) -> FeeAndTax? {
        guard price > 0, shares >= 1 else { return nil }
        let value = price * Decimal(shares)
        guard let fee = fee(forValue: value, shares: shares, settings: settings),
              let tax = side == .sell ? roundedDown(value * taxCategory.rate) : 0
        else { return nil }
        return FeeAndTax(fee: fee, tax: tax)
    }

    private static func fee(forValue value: Decimal, shares: Int, settings: FeeSettings) -> Int? {
        guard let calculated = roundedDown(value * standardFeeRate * settings.discount / 10) else { return nil }
        let minimum = shares >= wholeLotShares ? settings.wholeLotMinimumFee : settings.oddLotMinimumFee
        return max(calculated, minimum)
    }

    /// Nil when the result is not a number or does not fit in a record.
    private static func roundedDown(_ value: Decimal) -> Int? {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .down)
        guard result.isFinite, result <= largestAmount else { return nil }
        return NSDecimalNumber(decimal: result).intValue
    }
}
