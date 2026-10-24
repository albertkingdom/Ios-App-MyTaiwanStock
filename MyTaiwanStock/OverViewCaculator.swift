//
//  OverView.swift
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
/// 100.145 rounds the way it reads.
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

    /// Total value of the buys divided by the shares bought; nil when there is no buy.
    func averageBuyPrice() -> Decimal? {
        average(of: lines.filter { $0.side == .buy })
    }

    /// Total value of the sells divided by the shares sold; nil when there is no sell.
    func averageSellPrice() -> Decimal? {
        average(of: lines.filter { $0.side == .sell })
    }

    func totalAsset() -> Float? {
        guard let stockPrice else { return nil }
        return Float(amount) * stockPrice
    }

    private func average(of trades: [TradeLine]) -> Decimal? {
        let shares = trades.reduce(0) { $0 + $1.shares }
        guard shares > 0 else { return nil }
        let value = trades.reduce(Decimal(0)) { $0 + $1.price * Decimal($1.shares) }
        return value / Decimal(shares)
    }

    /// A price for display: two decimal places rounded half up, or a dash when there is none.
    static func format(_ price: Decimal?) -> String {
        guard let price else { return "-" }
        var input = price
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        return String(format: "%.2f", NSDecimalNumber(decimal: rounded).doubleValue)
    }
}
