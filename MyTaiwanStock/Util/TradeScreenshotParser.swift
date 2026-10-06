//
//  TradeScreenshotParser.swift
//  MyTaiwanStock
//

import Foundation

/// Reads the trade list of the 投資先生 trade detail screen from positioned text boxes.
///
/// Each trade is a two-line group: the upper line has the year fragment ("2026/"), stock
/// name, price and net amount; the lower line has the month/day, trade type, shares and
/// profit or loss. Lines are found by position, never by the order the text boxes come in.
/// Positions use Vision coordinates, where a larger y is higher on the screen.
enum TradeScreenshotParser {

    // Labels of the expanded detail block, the summary rows and the table header. A box with
    // one of these, and everything on its row, is not part of any trade.
    private static let ignoredLabels = [
        "委託書號", "持有成本", "價金", "手續費", "交易稅", "配息總額", "報酬率", "幣別", "沖抵明細",
        "總應收付", "總損益", "總價金", "總手續費", "總交易稅",
        "日期", "名稱", "價格/股數", "應收付/損益",
    ]

    /// Odd-lot trades only. Their share column is in shares, which is what `InvestHistory.amount`
    /// stores. Whole-lot rows ("現股買進"/"現股賣出") are recognized but flagged unsupported: no
    /// whole-lot screenshot exists, so it is unknown whether that column shows shares or lots.
    static let supportedTradeTypes: Set<String> = [
        "盤中零股買進", "盤中零股賣出", "盤後零股買進", "盤後零股賣出",
    ]

    /// The upper line must lie this many type-box heights above the lower line.
    private static let upperLineDistance = 0.5...2.5

    private struct Line {
        var boxes: [RecognizedTextBox]
        var midY: CGFloat
        var height: CGFloat
    }

    static func parse(boxes: [RecognizedTextBox]) -> [ParsedTrade] {
        let lines = group(removeIgnored(boxes))
        var trades: [ParsedTrade] = []

        for (index, line) in lines.enumerated() {
            guard let anchor = typeAnchor(in: line) else { continue }
            let upper = upperLine(above: index, in: lines, anchorHeight: anchor.height)
            trades.append(makeTrade(lower: line, anchor: anchor, upper: upper))
        }
        return trades
    }

    // MARK: ignoring non-trade text

    private static func removeIgnored(_ boxes: [RecognizedTextBox]) -> [RecognizedTextBox] {
        let ignored = boxes.filter { box in ignoredLabels.contains { box.text.contains($0) } }
        return boxes.filter { box in
            !ignored.contains { label in
                abs(label.midY - box.midY) <= 0.5 * max(label.boundingBox.height, box.boundingBox.height)
            }
        }
    }

    // MARK: lines

    /// Groups boxes into lines from top to bottom; boxes whose vertical centers are within
    /// half a box height of each other share a line. Each line is ordered left to right.
    private static func group(_ boxes: [RecognizedTextBox]) -> [Line] {
        var lines: [Line] = []
        for box in boxes.sorted(by: { $0.midY > $1.midY }) {
            if let last = lines.indices.last,
               abs(lines[last].midY - box.midY) <= 0.5 * max(lines[last].height, box.boundingBox.height) {
                lines[last].boxes.append(box)
                lines[last].height = max(lines[last].height, box.boundingBox.height)
            } else {
                lines.append(Line(boxes: [box], midY: box.midY, height: box.boundingBox.height))
            }
        }
        return lines.map { line in
            var sorted = line
            sorted.boxes.sort { $0.boundingBox.minX < $1.boundingBox.minX }
            return sorted
        }
    }

    private struct Anchor {
        let box: RecognizedTextBox
        let tradeType: String
        var height: CGFloat { box.boundingBox.height }
    }

    /// The trade type text ("盤中零股買進", "融資賣出"...) marks the lower line of a trade.
    private static func typeAnchor(in line: Line) -> Anchor? {
        for box in line.boxes {
            let text = stripped(box.text)
            if let match = text.range(of: #"[一-鿿]*(買進|賣出)$"#, options: .regularExpression) {
                return Anchor(box: box, tradeType: String(text[match]))
            }
        }
        return nil
    }

    /// The line directly above the anchor line, if it is close enough and has a year fragment.
    private static func upperLine(above index: Int, in lines: [Line], anchorHeight: CGFloat) -> Line? {
        guard index > 0 else { return nil }
        let lower = lines[index]
        let candidate = lines[index - 1]
        let distance = (candidate.midY - lower.midY) / anchorHeight
        guard upperLineDistance.contains(Double(distance)),
              candidate.boxes.contains(where: { yearFragment(in: $0.text) != nil })
        else { return nil }
        return candidate
    }

    // MARK: building a trade

    private static func makeTrade(lower: Line, anchor: Anchor, upper: Line?) -> ParsedTrade {
        var name = ""
        var price: Float?
        var year: Int?

        if let upper {
            var numbers: [String] = []
            for box in upper.boxes {
                var text = stripped(box.text)
                if let found = yearFragment(in: text) {
                    year = found.year
                    text = String(text[found.remainder...])
                }
                guard !text.isEmpty else { continue }
                if isNumber(text) {
                    numbers.append(text)
                } else if name.isEmpty {
                    name = text
                }
            }
            // Columns are price, then net amount; the net amount is not needed.
            price = numbers.first.flatMap { Float(removingSeparators($0)) }
        }

        var monthDay: (month: Int, day: Int)?
        var shares: Int?
        var afterType = false
        for box in lower.boxes {
            let text = stripped(box.text)
            if monthDay == nil, let found = monthDayFragment(in: text) { monthDay = found }
            if box == anchor.box {
                afterType = true
                continue
            }
            if afterType, shares == nil, isNumber(text), !text.contains(".") {
                shares = Int(removingSeparators(text))
            }
        }

        let tradeType = anchor.tradeType
        return ParsedTrade(
            stockName: name,
            date: makeDate(year: year, monthDay: monthDay),
            price: price,
            amount: shares,
            side: tradeType.hasSuffix("賣出") ? .sell : .buy,
            tradeTypeText: tradeType,
            isSupportedType: supportedTradeTypes.contains(tradeType))
    }

    private static func makeDate(year: Int?, monthDay: (month: Int, day: Int)?) -> Date? {
        guard let year, let monthDay else { return nil }
        let components = DateComponents(year: year, month: monthDay.month, day: monthDay.day)
        let calendar = TaipeiCalendar.calendar
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.month, .day], from: date).month == monthDay.month
        else { return nil }
        return date
    }

    // MARK: text helpers

    private static func stripped(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private static func removingSeparators(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: "")
    }

    private static func isNumber(_ text: String) -> Bool {
        text.range(of: #"^[-+]?[\d,]+(\.\d+)?$"#, options: .regularExpression) != nil
    }

    /// "2026/" or "2026/元大台灣50" (a merged text box).
    private static func yearFragment(in text: String) -> (year: Int, remainder: String.Index)? {
        let stripped = stripped(text)
        guard let match = stripped.range(of: #"^\d{4}/"#, options: .regularExpression),
              let year = Int(stripped[stripped.startIndex..<stripped.index(match.upperBound, offsetBy: -1)])
        else { return nil }
        return (year, match.upperBound)
    }

    private static func monthDayFragment(in text: String) -> (month: Int, day: Int)? {
        guard let match = text.range(of: #"\d{1,2}/\d{1,2}"#, options: .regularExpression) else { return nil }
        let parts = text[match].split(separator: "/").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}
