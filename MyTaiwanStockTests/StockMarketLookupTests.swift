//
//  StockMarketLookupTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class StockMarketLookupTests: XCTestCase {

    private let lookup = StockMarketLookup(marketByCode: ["6488": .otc, "2330": .tse])
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func queryItem(_ name: String, in url: URL?) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first { $0.name == name }?.value
    }

    func test_market_for_known_and_unknown_codes() {
        XCTAssertEqual(lookup.market(forCode: "6488"), .otc)
        XCTAssertEqual(lookup.market(forCode: "2330"), .tse)
        XCTAssertEqual(lookup.market(forCode: "9999"), .tse)
    }

    func test_ex_channel_prefix_examples() {
        XCTAssertEqual(lookup.exChannel(forCode: "2330"), "tse_2330.tw")
        XCTAssertEqual(lookup.exChannel(forCode: "6488"), "otc_6488.tw")
        XCTAssertEqual(lookup.exChannel(forCode: "9999"), "tse_9999.tw")
    }

    func test_mixed_query() {
        XCTAssertEqual(lookup.exChannelQuery(forCodes: ["6488", "2330"]), "otc_6488.tw|tse_2330.tw")
    }

    func test_quote_request_url_uses_market_prefix() {
        let url = TWSEStockInfoFetcher.requestURL(stockList: ["6488", "2330"], lookup: lookup)

        XCTAssertEqual(queryItem("ex_ch", in: url), "otc_6488.tw|tse_2330.tw")
        XCTAssertEqual(queryItem("json", in: url), "1")
    }

    func test_file_is_written_and_read_back() throws {
        let fileURL = directory.appendingPathComponent(StockMarketLookup.fileName)

        try StockMarketLookup.write(["6488": .otc, "2330": .tse], to: fileURL)
        let loaded = StockMarketLookup(contentsOf: fileURL)

        XCTAssertEqual(loaded.market(forCode: "6488"), .otc)
        XCTAssertEqual(loaded.market(forCode: "2330"), .tse)
    }

    func test_identical_content_is_not_rewritten() throws {
        let fileURL = directory.appendingPathComponent(StockMarketLookup.fileName)

        let first = try StockMarketLookup.write(["6488": .otc], to: fileURL)
        let second = try StockMarketLookup.write(["6488": .otc], to: fileURL)
        let changed = try StockMarketLookup.write(["6488": .otc, "2330": .tse], to: fileURL)

        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertTrue(changed)
    }

    func test_missing_or_unreadable_file_defaults_to_tse() throws {
        let missing = StockMarketLookup(contentsOf: directory.appendingPathComponent("missing.json"))
        XCTAssertEqual(missing.market(forCode: "6488"), .tse)
        XCTAssertEqual(StockMarketLookup(contentsOf: nil).market(forCode: "6488"), .tse)

        let garbage = directory.appendingPathComponent("garbage.json")
        try Data("nope".utf8).write(to: garbage)
        XCTAssertEqual(StockMarketLookup(contentsOf: garbage).market(forCode: "6488"), .tse)
    }
}
