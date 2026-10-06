//
//  StockNameResolverTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class StockNameResolverTests: XCTestCase {

    private func entry(_ code: String, _ name: String, _ market: StockMarket = .tse) -> StockListEntry {
        StockListEntry(code: code, name: name, market: market)
    }

    private lazy var resolver = StockNameResolver(entries: [
        entry("0050", "元大台灣50"), entry("2344", "華邦電"), entry("2330", "台積電"), entry("2379", "瑞昱"),
        entry("00850", "元大MSCI A股"),
        entry("6488", "環球晶", .otc),
        entry("8888", "重複名"), entry("8889", "重複名"),
    ])

    func test_names_from_the_screenshots_resolve_to_their_codes() {
        XCTAssertEqual(resolver.resolve(name: "元大台灣50"), "0050")
        XCTAssertEqual(resolver.resolve(name: "華邦電"), "2344")
        XCTAssertEqual(resolver.resolve(name: "台積電"), "2330")
        XCTAssertEqual(resolver.resolve(name: "瑞昱"), "2379")
        XCTAssertEqual(resolver.resolve(name: "環球晶"), "6488")
    }

    func test_list_name_with_spaces_matches_ocr_text_without_spaces() {
        XCTAssertEqual(resolver.resolve(name: "元大MSCIA股"), "00850")
        XCTAssertEqual(resolver.resolve(name: "元大MSCI A股"), "00850")
    }

    func test_ocr_text_with_stray_spaces_matches() {
        XCTAssertEqual(resolver.resolve(name: "元大 台灣50"), "0050")
        XCTAssertEqual(resolver.resolve(name: " 台積電 "), "2330")
    }

    func test_full_width_and_half_width_forms_match() {
        let resolver = StockNameResolver(entries: [entry("0050", "元大台灣50")])

        XCTAssertEqual(resolver.resolve(name: "元大台灣５０"), "0050")
        XCTAssertEqual(StockNameResolver(entries: [entry("00850", "元大MSCI A股")]).resolve(name: "元大ＭＳＣＩ　Ａ股"), "00850")
    }

    func test_unknown_name_is_not_resolved() {
        XCTAssertNil(resolver.resolve(name: "不存在的股票"))
        XCTAssertNil(resolver.resolve(name: ""))
    }

    func test_partial_names_are_not_fuzzy_matched() {
        XCTAssertNil(resolver.resolve(name: "台積"))
        XCTAssertNil(resolver.resolve(name: "元大台灣"))
    }

    func test_duplicate_names_are_not_resolved() {
        XCTAssertNil(resolver.resolve(name: "重複名"))
    }

    @MainActor
    func test_real_list_resolves_an_otc_stock() {
        let repository = StockListRepository(
            cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            marketLookupURL: nil)

        let resolver = StockNameResolver(entries: repository.entries)

        XCTAssertEqual(resolver.resolve(name: "環球晶"), "6488")
        XCTAssertEqual(resolver.resolve(name: "台積電"), "2330")
    }
}
