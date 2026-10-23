//
//  TradeScreenshotParserTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class TradeScreenshotParserTests: XCTestCase {

    typealias Fixtures = TradeScreenshotFixtures

    private func day(_ date: Date?) -> String? {
        guard let date else { return nil }
        let parts = TaipeiCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    private func summary(_ trade: ParsedTrade) -> String {
        let side = trade.side == .buy ? "買" : "賣"
        return "\(trade.stockName) \(side) \(trade.amount.map(String.init) ?? "nil") \(trade.price.map { String($0) } ?? "nil") \(day(trade.date) ?? "nil")"
    }

    // MARK: collapsed and expanded screens

    func test_collapsed_screen_parses_both_odd_lot_buys() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.collapsed)

        XCTAssertEqual(trades.map(summary), [
            "元大台灣50 買 5 112.55 2026-09-30",
            "華邦電 買 3 179.5 2026-10-01",
        ])
        XCTAssertTrue(trades.allSatisfy { $0.isSupportedType })
        XCTAssertEqual(trades.map(\.tradeTypeText), ["盤中零股買進", "盤中零股買進"])
    }

    func test_expanded_screen_parses_a_buy_and_a_sell() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.expanded)

        XCTAssertEqual(trades.map(summary), [
            "台積電 買 1 2470.0 2026-09-22",
            "瑞昱 賣 10 757.0 2026-09-23",
        ])
    }

    func test_thousands_separator_is_removed() {
        let page = Fixtures.collapsedPage
        let pixels: [Fixtures.PixelBox] = [
            ("2026/", 40, 500, 158, 550), ("元大台灣50", 205, 500, 435, 550),
            ("1,125.50", 540, 500, 688, 550), ("-1,125,500", 840, 500, 960, 550),
            ("09/30", 40, 585, 158, 632), ("盤中零股買進", 197, 585, 443, 632),
            ("1,000", 600, 585, 688, 632), ("--", 936, 585, 960, 632),
        ]

        let trades = TradeScreenshotParser.parse(boxes: Fixtures.boxes(pixels, on: page))

        XCTAssertEqual(trades.map(summary), ["元大台灣50 買 1000 1125.5 2026-09-30"])
    }

    // MARK: broken layouts

    func test_top_row_cut_off_is_incomplete_and_borrows_nothing() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.topRowCutOff)

        XCTAssertEqual(trades.count, 2)
        let cutOff = trades[0]
        XCTAssertEqual(cutOff.stockName, "")
        XCTAssertNil(cutOff.price)
        XCTAssertNil(cutOff.date)
        XCTAssertEqual(summary(trades[1]), "華邦電 買 3 179.5 2026-10-01")
    }

    func test_merged_text_boxes_still_parse() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.mergedBoxes)

        XCTAssertEqual(trades.map(summary), ["元大台灣50 買 5 112.55 2026-09-30"])
    }

    func test_name_ending_with_plus_sign_parses() {
        let page = Fixtures.collapsedPage
        let boxes = Fixtures.boxes(Fixtures.collapsedHeader + [
            ("2026/", 40, 500, 158, 550), ("統一FANG+", 205, 500, 435, 550),
            ("112.55", 552, 500, 688, 550), ("-563", 870, 500, 960, 550),
        ] + Fixtures.row0Lower, on: page)

        XCTAssertEqual(TradeScreenshotParser.parse(boxes: boxes).map(summary), ["統一FANG+ 買 5 112.55 2026-09-30"])
    }

    func test_plus_sign_split_into_its_own_text_box_stays_in_the_name() {
        let page = Fixtures.collapsedPage
        let boxes = Fixtures.boxes(Fixtures.collapsedHeader + [
            ("2026/", 40, 500, 158, 550), ("統一FANG", 205, 500, 400, 550), ("+", 402, 500, 435, 550),
            ("112.55", 552, 500, 688, 550), ("-563", 870, 500, 960, 550),
        ] + Fixtures.row0Lower, on: page)

        XCTAssertEqual(TradeScreenshotParser.parse(boxes: boxes).map(summary), ["統一FANG+ 買 5 112.55 2026-09-30"])
    }

    func test_plus_sign_box_far_from_the_name_is_not_part_of_it() {
        let page = Fixtures.collapsedPage
        let boxes = Fixtures.boxes(Fixtures.collapsedHeader + [
            ("2026/", 40, 500, 158, 550), ("元大台灣50", 205, 500, 435, 550), ("+", 500, 500, 520, 550),
            ("112.55", 552, 500, 688, 550), ("1,234", 870, 500, 960, 550),
        ] + Fixtures.row0Lower, on: page)

        XCTAssertEqual(TradeScreenshotParser.parse(boxes: boxes).map(summary), ["元大台灣50 買 5 112.55 2026-09-30"])
    }

    func test_split_chinese_and_latin_name_fragments_resolve_to_the_stock_code() {
        let cases: [[Fixtures.PixelBox]] = [
            [("統一", 205, 500, 300, 550), ("FANG", 305, 500, 400, 550), ("+", 402, 500, 435, 550)],
            [("統", 205, 500, 250, 550), ("—", 252, 500, 290, 550), ("FANG+", 292, 500, 435, 550)],
            [("統一", 205, 500, 300, 550), ("FANG+", 305, 500, 435, 550)],
        ]
        for fragments in cases {
            let boxes = Fixtures.boxes([
                ("2026/", 40, 500, 158, 550),
                ("144.20", 552, 500, 688, 550), ("-722", 870, 500, 960, 550),
            ] + fragments + Fixtures.row0Lower, on: Fixtures.collapsedPage)
            let trades = TradeScreenshotParser.parse(boxes: boxes)
            XCTAssertEqual(trades.count, 1)
            let resolver = StockNameResolver(entries: [StockListEntry(code: "00757", name: "統一FANG+", market: .tse)])
            XCTAssertEqual(trades.first.flatMap { resolver.resolve(name: $0.stockName) }, "00757")
            XCTAssertEqual(trades.first?.price, 144.2)
            XCTAssertEqual(trades.first?.amount, 5)
        }
    }

    func test_numeric_name_fragment_does_not_replace_the_price() {
        let boxes = Fixtures.boxes([
            ("2026/", 40, 500, 158, 550), ("元大台灣", 205, 500, 380, 550), ("50", 382, 500, 435, 550),
            ("112", 450, 500, 688, 550), ("-563", 870, 500, 960, 550),
        ] + Fixtures.row0Lower, on: Fixtures.collapsedPage)
        let trades = TradeScreenshotParser.parse(boxes: boxes)
        XCTAssertEqual(trades.first?.stockName, "元大台灣50")
        XCTAssertEqual(trades.first?.price, 112)
    }

    func test_user_fang_screenshot_vision_output_does_not_take_profit_loss_as_shares() {
        let boxes = TradeScreenshotVisionFixtures.fangMissingShares
        let trades = TradeScreenshotParser.parse(boxes: boxes)
        XCTAssertEqual(trades.count, 1)
        XCTAssertEqual(trades.first?.stockName, "統一FANG+")
        XCTAssertEqual(trades.first?.price, 144.2)
        XCTAssertEqual(trades.first.flatMap { day($0.date) }, "2026-10-20")
        XCTAssertNil(trades.first?.amount, "Vision missed 5 and read the profit/loss placeholder as 11")
    }

    func test_wide_share_count_under_a_narrow_price_stays_in_the_share_column() {
        let boxes = Fixtures.boxes([
            ("2026/", 40, 500, 158, 550), ("台積電", 205, 500, 435, 550),
            ("9", 665, 500, 688, 550), ("9,000", 840, 500, 960, 550),
            ("10/20", 40, 585, 158, 632), ("盤中零股賣出", 197, 585, 443, 632),
            ("1,000", 560, 585, 688, 632), ("100", 870, 585, 960, 632),
        ], on: Fixtures.collapsedPage)
        let trades = TradeScreenshotParser.parse(boxes: boxes)
        XCTAssertEqual(trades.first?.price, 9)
        XCTAssertEqual(trades.first?.amount, 1000)
    }

    func test_missing_share_count_with_a_positive_profit_stays_incomplete() {
        let boxes = Fixtures.boxes([
            ("2026/", 40, 500, 158, 550), ("台積電", 205, 500, 435, 550),
            ("9", 665, 500, 688, 550), ("9,000", 840, 500, 960, 550),
            ("10/20", 40, 585, 158, 632), ("盤中零股賣出", 197, 585, 443, 632),
            ("100", 870, 585, 960, 632),
        ], on: Fixtures.collapsedPage)
        XCTAssertNil(TradeScreenshotParser.parse(boxes: boxes).first?.amount)
    }

    // MARK: ignored text

    func test_summary_and_header_rows_alone_produce_no_trade() {
        let boxes = Fixtures.boxes(Fixtures.collapsedHeader, on: Fixtures.collapsedPage)

        XCTAssertTrue(TradeScreenshotParser.parse(boxes: boxes).isEmpty)
    }

    func test_expanded_detail_text_does_not_create_or_change_trades() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.expanded)

        XCTAssertEqual(trades.count, 2)
        XCTAssertEqual(trades[1].stockName, "瑞昱")
        XCTAssertEqual(trades[1].amount, 10)
        XCTAssertEqual(trades[1].price, 757.0)
    }

    // MARK: trade types

    func test_margin_trade_is_kept_but_marked_unsupported() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.withMarginTrade)

        XCTAssertEqual(trades.map(\.stockName), ["元大台灣50", "長榮"])
        XCTAssertEqual(trades.map(\.isSupportedType), [true, false])
        XCTAssertEqual(trades[1].tradeTypeText, "融資買進")
        XCTAssertEqual(summary(trades[1]), "長榮 買 100 200.0 2026-10-02")
    }

    func test_whole_lot_trades_are_unsupported_until_the_share_unit_is_confirmed() {
        // Only odd-lot screenshots exist, so it is unknown whether a whole-lot row shows shares or lots.
        for type in ["現股買進", "現股賣出"] {
            let pixels: [Fixtures.PixelBox] = [
                ("2026/", 40, 500, 158, 550), ("台積電", 205, 500, 435, 550),
                ("2470.00", 552, 500, 688, 550), ("-2,472,000", 830, 500, 960, 550),
                ("09/22", 40, 585, 158, 632), (type, 215, 585, 425, 632),
                ("1", 665, 585, 688, 632), ("--", 936, 585, 960, 632),
            ]

            let trades = TradeScreenshotParser.parse(boxes: Fixtures.boxes(pixels, on: Fixtures.collapsedPage))

            XCTAssertEqual(trades.map(\.isSupportedType), [false], type)
            XCTAssertEqual(trades.map(\.tradeTypeText), [type])
        }
    }

    func test_all_supported_trade_types() {
        let types = ["盤中零股買進", "盤中零股賣出", "盤後零股買進", "盤後零股賣出"]
        for type in types {
            let pixels: [Fixtures.PixelBox] = [
                ("2026/", 40, 500, 158, 550), ("台積電", 205, 500, 435, 550),
                ("2470.00", 552, 500, 688, 550), ("-2,472", 870, 500, 960, 550),
                ("09/22", 40, 585, 158, 632), (type, 197, 585, 443, 632),
                ("1", 665, 585, 688, 632), ("--", 936, 585, 960, 632),
            ]

            let trades = TradeScreenshotParser.parse(boxes: Fixtures.boxes(pixels, on: Fixtures.collapsedPage))

            XCTAssertEqual(trades.count, 1, type)
            XCTAssertTrue(trades[0].isSupportedType, type)
            XCTAssertEqual(trades[0].side, type.hasSuffix("賣出") ? .sell : .buy, type)
        }
    }

    func test_unknown_trade_types_are_unsupported() {
        for type in ["當沖買進", "定期定額買進", "融券賣出"] {
            let pixels: [Fixtures.PixelBox] = [
                ("2026/", 40, 500, 158, 550), ("台積電", 205, 500, 435, 550),
                ("2470.00", 552, 500, 688, 550), ("-2,472", 870, 500, 960, 550),
                ("09/22", 40, 585, 158, 632), (type, 197, 585, 443, 632),
                ("1", 665, 585, 688, 632), ("--", 936, 585, 960, 632),
            ]

            let trades = TradeScreenshotParser.parse(boxes: Fixtures.boxes(pixels, on: Fixtures.collapsedPage))

            XCTAssertEqual(trades.map(\.isSupportedType), [false], type)
        }
    }

    // MARK: missing year

    func test_missing_year_leaves_date_empty_but_keeps_other_fields() {
        let trades = TradeScreenshotParser.parse(boxes: Fixtures.topRowCutOff)

        XCTAssertNil(trades[0].date)
        XCTAssertEqual(trades[0].amount, 5)
    }

    // MARK: text boxes exactly as Vision returned them for the real screenshots

    func test_vision_output_of_the_collapsed_screenshot() {
        let trades = TradeScreenshotParser.parse(boxes: TradeScreenshotVisionFixtures.collapsed)

        XCTAssertEqual(trades.map(summary), [
            "元大台灣50 買 5 112.55 2026-09-30",
            "華邦電 買 3 179.5 2026-10-01",
        ])
    }

    func test_vision_output_of_the_expanded_screenshot() {
        let trades = TradeScreenshotParser.parse(boxes: TradeScreenshotVisionFixtures.expanded)

        XCTAssertEqual(trades.map(summary), [
            "台積電 買 1 2470.0 2026-09-22",
            "瑞昱 賣 10 757.0 2026-09-23",
        ])
    }
}

