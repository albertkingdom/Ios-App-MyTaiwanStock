//
//  TradeImportModels.swift
//  MyTaiwanStock
//

import Foundation

/// One piece of recognized text with its position.
/// `boundingBox` uses the Vision coordinate system: normalized (0 to 1), origin at the
/// lower left corner, so a larger y is higher on the screen.
struct RecognizedTextBox: Equatable {
    let text: String
    let boundingBox: CGRect

    var midX: CGFloat { boundingBox.midX }
    var midY: CGFloat { boundingBox.midY }
}

enum TradeSide: Int, Equatable {
    case buy = 0
    case sell = 1
}

/// A trade read from a screenshot. Missing values mean the screenshot did not show them,
/// which makes the trade incomplete in the preview.
struct ParsedTrade: Equatable {
    var stockName: String
    /// Calendar day of the trade, as midnight in the Asia/Taipei time zone.
    var date: Date?
    var price: Float?
    /// Shares ("股"), the unit `InvestHistory.amount` uses.
    var amount: Int?
    var side: TradeSide
    var tradeTypeText: String
    var isSupportedType: Bool
}

enum TaipeiCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Taipei")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
