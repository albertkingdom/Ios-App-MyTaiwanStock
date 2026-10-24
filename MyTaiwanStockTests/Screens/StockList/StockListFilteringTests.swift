//
//  StockListFilteringTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class StockListFilteringTests: XCTestCase {

    private func otcJSON(_ rows: [(String, String)]) -> Data {
        let items = rows.map { code, name in
            // Extra fields mimic the real payload and must be ignored.
            #"{"Date":"1151002","SecuritiesCompanyCode":"\#(code)","CompanyName":"\#(name)","Close":"10.00","Change":"0.1"}"#
        }
        return Data("[\(items.joined(separator: ","))]".utf8)
    }

    private func twseJSON(_ rows: [(String, String)]) -> Data {
        let items = rows.map { code, name in
            #"{"Date":"1151002","Code":"\#(code)","Name":"\#(name)","TradeVolume":"1"}"#
        }
        return Data("[\(items.joined(separator: ","))]".utf8)
    }

    func test_otc_warrants_are_excluded() throws {
        let data = otcJSON([
            ("710000", "精材群益5C購02"), ("700019", "宏捷科統一5C購01"),
            ("73000U", "宜鼎國票63售01"), ("72400U", "博智群益5A售02"),
            ("6488", "環球晶"), ("00679B", "元大美債20年"),
            ("006201", "元大富櫃50"), ("00411A", "主動統一前沿科技"),
        ])

        let entries = try StockListParser.parseOTC(data)

        XCTAssertEqual(Set(entries.map(\.code)), ["6488", "00679B", "006201", "00411A"])
        XCTAssertTrue(entries.allSatisfy { $0.market == .otc })
        XCTAssertEqual(entries.first { $0.code == "6488" }?.name, "環球晶")
    }

    func test_otc_filter_rule_examples() {
        XCTAssertTrue(StockListParser.isKeptOTCCode("6488"))      // 4 characters
        XCTAssertTrue(StockListParser.isKeptOTCCode("00679B"))    // starts with 00
        XCTAssertFalse(StockListParser.isKeptOTCCode("710000"))   // 6 characters, starts with 71
        XCTAssertFalse(StockListParser.isKeptOTCCode("73000U"))   // 6 characters, starts with 73
    }

    func test_twse_keeps_every_entry_as_tse() throws {
        let data = twseJSON([("00981A", "主動統一台股增長"), ("2330", "台積電"), ("020001", "富邦存股雙十N")])

        let entries = try StockListParser.parseTWSE(data)

        XCTAssertEqual(entries.map(\.code), ["00981A", "2330", "020001"])
        XCTAssertTrue(entries.allSatisfy { $0.market == .tse })
    }

    func test_invalid_json_throws() {
        XCTAssertThrowsError(try StockListParser.parseTWSE(Data("not json".utf8)))
        XCTAssertThrowsError(try StockListParser.parseOTC(Data("{}".utf8)))
    }

    func test_merge_prefers_twse_when_code_is_in_both_sources() {
        let tse = [StockListEntry(code: "1234", name: "上市名", market: .tse)]
        let otc = [
            StockListEntry(code: "1234", name: "上櫃名", market: .otc),
            StockListEntry(code: "6488", name: "環球晶", market: .otc),
        ]

        let merged = StockListParser.merge(tse: tse, otc: otc)

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.code == "1234" }, StockListEntry(code: "1234", name: "上市名", market: .tse))
        XCTAssertEqual(merged.first { $0.code == "6488" }?.market, .otc)
    }
}
