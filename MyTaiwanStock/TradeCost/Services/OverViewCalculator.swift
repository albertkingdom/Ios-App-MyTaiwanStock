//
//  OverViewCalculator.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/11/24.
//

import Foundation

/// One buy or sell record reduced to the numbers the overview needs.
struct TradeLine: Equatable {
    let side: TradeSide
    let shares: Int
    let price: Decimal
    /// Nil for a record saved before fees were stored.
    let fee: Int?
}

/// Holdings and average prices of one stock. Everything is computed in decimals so that a price such as
/// 100.145 rounds the way it reads. The average buy price includes the buy fees; an unknown fee counts as 0.
final class OverViewCalculator {
    /// The holdings: shares bought minus shares sold. Negative when more was sold than bought.
    let amount: Int
    var stockPrice: Float?
    private let lines: [TradeLine]

    init(lines: [TradeLine], stockPrice: Float?) {
        self.lines = lines
        self.stockPrice = stockPrice
        self.amount = lines.reduce(0) { $0 + ($1.side == .buy ? $1.shares : -$1.shares) }
    }

    convenience init(historys: [HistoryCellModel], stockPrice: Float?) {
        self.init(lines: historys.map(\.tradeLine), stockPrice: stockPrice)
    }

    /// Total value of the buys plus their fees, divided by the shares bought; nil when there is no buy.
    func averageBuyPrice() -> Decimal? {
        average(of: lines.filter { $0.side == .buy }, includingFees: true)
    }

    /// Total value of the sells divided by the shares sold, without fees; nil when there is no sell.
    func averageSellPrice() -> Decimal? {
        average(of: lines.filter { $0.side == .sell }, includingFees: false)
    }

    /// True when a buy was saved before fees were stored, so the average buy price may be too low.
    var hasBuyWithUnknownFee: Bool {
        lines.contains { $0.side == .buy && $0.fee == nil }
    }

    /// The holdings at the current price; nil without a price or when nothing is held.
    func totalAsset() -> Float? {
        guard let stockPrice, amount > 0 else { return nil }
        return Float(amount) * stockPrice
    }

    /// The profit of one buy as a percentage of its cost including the fee; nil for a sell, without a
    /// current price, or when the record has no cost.
    static func profitPercent(of line: TradeLine, currentPrice: Decimal?) -> Decimal? {
        guard line.side == .buy, let currentPrice, line.shares > 0 else { return nil }
        let cost = (line.price * Decimal(line.shares) + Decimal(line.fee ?? 0)) / Decimal(line.shares)
        guard cost > 0 else { return nil }
        return (currentPrice - cost) / cost * 100
    }

    private func average(of trades: [TradeLine], includingFees: Bool) -> Decimal? {
        let shares = trades.reduce(0) { $0 + $1.shares }
        guard shares > 0 else { return nil }
        let value = trades.reduce(Decimal(0)) { $0 + $1.price * Decimal($1.shares) }
        let fees = includingFees ? trades.reduce(0) { $0 + ($1.fee ?? 0) } : 0
        return (value + Decimal(fees)) / Decimal(shares)
    }

    /// A price or percentage for display: two decimal places rounded half up, or a dash when there is none.
    static func format(_ price: Decimal?) -> String {
        guard let price else { return "-" }
        return String(format: "%.2f", NSDecimalNumber(decimal: rounded(price)).doubleValue)
    }

    /// Two decimal places, rounded half up: what `format` shows.
    static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }
}
