//
//  TradeScreenshotFixtures.swift
//  MyTaiwanStockTests
//
//  Text boxes transcribed from real screenshots of the 投資先生 trade detail screen.
//  Pixel rectangles use a top-left origin, like the screenshot; `boxes(...)` converts them
//  to Vision coordinates (normalized, origin at the lower left).
//

import CoreGraphics
@testable import MyTaiwanStock

enum TradeScreenshotFixtures {

    struct Page {
        let width: CGFloat
        let height: CGFloat
    }

    typealias PixelBox = (text: String, x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)

    static func boxes(_ pixels: [PixelBox], on page: Page) -> [RecognizedTextBox] {
        pixels.map { box in
            RecognizedTextBox(
                text: box.text,
                boundingBox: CGRect(
                    x: box.x0 / page.width,
                    y: 1 - box.y1 / page.height,
                    width: (box.x1 - box.x0) / page.width,
                    height: (box.y1 - box.y0) / page.height))
        }
    }

    // MARK: collapsed screenshot (1034 x 2000): 元大台灣50 and 華邦電, odd-lot buys

    static let collapsedPage = Page(width: 1034, height: 2000)

    /// Summary rows and table header above the trades.
    static let collapsedHeader: [PixelBox] = [
        ("總應收付", 14, 35, 195, 85), ("總損益", 530, 35, 665, 85),
        ("-1,102", 12, 110, 135, 150), ("0", 530, 110, 553, 150),
        ("總價金", 105, 180, 240, 225), ("總手續費", 427, 180, 607, 225), ("總交易稅", 770, 180, 952, 225),
        ("1,100", 118, 255, 228, 295), ("2", 505, 255, 530, 295), ("0", 850, 255, 875, 295),
        ("日期", 57, 410, 143, 455), ("名稱", 275, 410, 365, 455),
        ("價格/股數", 468, 410, 665, 455), ("應收付/損益", 703, 410, 945, 455),
    ]

    static let row0Upper: [PixelBox] = [
        ("2026/", 40, 500, 158, 550), ("元大台灣50", 205, 500, 435, 550),
        ("112.55", 552, 500, 688, 550), ("-563", 870, 500, 960, 550),
    ]
    static let row0Lower: [PixelBox] = [
        ("09/30", 40, 585, 158, 632), ("盤中零股買進", 197, 585, 443, 632),
        ("5", 665, 585, 688, 632), ("--", 936, 585, 960, 632),
    ]
    static let row1Upper: [PixelBox] = [
        ("2026/", 40, 670, 158, 716), ("華邦電", 253, 670, 387, 716),
        ("179.50", 552, 670, 688, 716), ("-539", 870, 670, 960, 716),
    ]
    static let row1Lower: [PixelBox] = [
        ("10/01", 40, 754, 158, 800), ("盤中零股買進", 197, 754, 443, 800),
        ("3", 665, 754, 688, 800), ("--", 936, 754, 960, 800),
    ]
    /// A margin trade, which the app does not support.
    static let marginUpper: [PixelBox] = [
        ("2026/", 40, 835, 158, 881), ("長榮", 270, 835, 370, 881),
        ("200.00", 552, 835, 688, 881), ("-20,000", 850, 835, 960, 881),
    ]
    static let marginLower: [PixelBox] = [
        ("10/02", 40, 920, 158, 966), ("融資買進", 215, 920, 425, 966),
        ("100", 640, 920, 688, 966), ("--", 936, 920, 960, 966),
    ]

    static var collapsed: [RecognizedTextBox] {
        boxes(collapsedHeader + row0Upper + row0Lower + row1Upper + row1Lower, on: collapsedPage)
    }

    /// First trade scrolled so only its lower line is visible; the summary rows are above it.
    static var topRowCutOff: [RecognizedTextBox] {
        boxes(collapsedHeader + row0Lower + row1Upper + row1Lower, on: collapsedPage)
    }

    static var withMarginTrade: [RecognizedTextBox] {
        boxes(collapsedHeader + row0Upper + row0Lower + marginUpper + marginLower, on: collapsedPage)
    }

    /// Vision sometimes returns neighbouring columns as one text box.
    static var mergedBoxes: [RecognizedTextBox] {
        boxes(collapsedHeader + [
            ("2026/ 元大台灣50", 40, 500, 435, 550), ("112.55", 552, 500, 688, 550), ("-563", 870, 500, 960, 550),
            ("09/30 盤中零股買進", 40, 585, 443, 632), ("5", 665, 585, 688, 632), ("--", 936, 585, 960, 632),
        ], on: collapsedPage)
    }

    // MARK: expanded screenshot (1260 x 1209): 台積電 buy and 瑞昱 sell, details open

    static let expandedPage = Page(width: 1260, height: 1209)

    static var expanded: [RecognizedTextBox] {
        boxes([
            // 台積電, odd-lot buy
            ("2026/", 48, 20, 190, 70), ("台積電", 312, 20, 470, 70), ("2470.00", 640, 20, 838, 70), ("-2,472", 1020, 20, 1170, 70),
            ("09/22", 48, 122, 193, 168), ("盤中零股買進", 240, 122, 538, 168), ("1", 812, 122, 832, 168), ("--", 1140, 122, 1170, 168),
            ("委託書號：", 30, 235, 228, 290), ("i025R", 310, 235, 445, 290), ("幣別：", 660, 235, 757, 290), ("新台幣", 842, 235, 990, 290),
            ("持有成本：", 30, 325, 228, 380), ("2,472", 310, 325, 440, 380), ("價金：", 660, 325, 757, 380), ("2,470", 842, 325, 970, 380),
            ("手續費：", 30, 410, 178, 462), ("2", 255, 410, 282, 462),
            // 瑞昱, odd-lot sell
            ("2026/", 48, 530, 190, 578), ("瑞昱", 337, 530, 443, 578), ("757.00", 672, 530, 838, 578), ("7,542", 1038, 530, 1170, 578),
            ("09/23", 48, 632, 193, 678), ("盤中零股賣出", 240, 632, 538, 678), ("10", 780, 632, 838, 678), ("-367", 1062, 632, 1170, 678),
            ("委託書號：", 30, 745, 228, 800), ("i01iF", 310, 745, 425, 800), ("幣別：", 660, 745, 757, 800), ("新台幣", 842, 745, 990, 800),
            ("持有成本：", 30, 835, 228, 890), ("7,909", 310, 835, 440, 890), ("報酬率：", 660, 835, 808, 890), ("-4.64%", 898, 835, 1055, 890),
            ("價金：", 30, 920, 128, 975), ("7,570", 212, 920, 340, 975), ("配息總額：", 660, 920, 858, 975), ("250", 940, 920, 1028, 975),
            ("手續費：", 30, 1005, 178, 1058), ("6", 255, 1005, 282, 1058), ("交易稅：", 660, 1005, 808, 1058), ("22", 898, 1005, 956, 1058),
            ("沖抵明細", 700, 1090, 900, 1150),
        ], on: expandedPage)
    }
}
