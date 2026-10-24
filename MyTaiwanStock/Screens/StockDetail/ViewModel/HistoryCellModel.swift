//
//  HistoryCellViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//

import Foundation

struct HistoryCellModel {
    var status: Int16 {
        return historyData.status
    } // 0: buy, 1: sell
    var dateString: String {
        return dateFormat(date: historyData.date!)
    }
    var priceString: String {
        return String(historyData.price)
    }
    var amountString: String {
        return String(historyData.amount)
    }
    /// The profit of a buy in percent including its fee, rounded to the two decimals the label shows so that
    /// the color agrees with the text; nil for a sell or without a current price.
    let revenueValue: Decimal?
    var revenueString: String {
        guard status == 0 else { return "N/A" }
        return "\(OverViewCalculator.format(revenueValue)) %"
    }
    /// The fee and the tax on a line of their own, a dash for a value that was never stored.
    var feeTaxString: String {
        "detailVC_fee_tax_format".localized(with: [Self.amountText(historyData.fee), Self.amountText(historyData.tax)])
    }
    let historyData: InvestHistory
    let currentStockPriceString: String

    /// The numbers the overview needs. The price goes through its shortest text so that 112.55 stays 112.55.
    let tradeLine: TradeLine
    
    init(historyData: InvestHistory, currentStockPrice: String) {
        self.historyData = historyData
        self.currentStockPriceString = currentStockPrice
        // Decimal(string:) reads a dash as 0, so the text has to be a real number first.
        let currentPrice = Float(currentStockPrice).flatMap { Decimal(string: String($0)) }
        let line = TradeLine(
            side: historyData.status == 1 ? .sell : .buy,
            shares: Int(historyData.amount),
            price: Decimal(string: String(historyData.price)) ?? 0,
            fee: historyData.fee?.intValue)
        self.tradeLine = line
        self.revenueValue = OverViewCalculator.profitPercent(of: line, currentPrice: currentPrice)
            .map(OverViewCalculator.rounded)
    }
    
    
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy\nMM-dd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }

    private static func amountText(_ amount: NSNumber?) -> String {
        amount.map { String($0.intValue) } ?? "-"
    }
}
