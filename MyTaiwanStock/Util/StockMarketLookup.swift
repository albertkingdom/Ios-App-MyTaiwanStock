//
//  StockMarketLookup.swift
//  MyTaiwanStock
//
//  Depends only on Foundation so the widget extension can compile it cheaply.
//

import Foundation

/// Maps a stock code to its market so quote requests use the right prefix:
/// `tse_` for listed stocks and `otc_` for over-the-counter stocks.
///
/// The main app writes the lookup into the App Group container whenever the stock list is
/// loaded or refreshed; the widget only reads it. A code that is not in the lookup, or a
/// lookup that cannot be read, falls back to `tse` (the behavior before OTC support).
struct StockMarketLookup {
    static let appGroupIdentifier = "group.a2006mike.myTaiwanStock"
    static let fileName = "StockMarkets.json"

    private let marketByCode: [String: StockMarket]

    init(marketByCode: [String: StockMarket] = [:]) {
        self.marketByCode = marketByCode
    }

    init(contentsOf fileURL: URL?) {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: StockMarket].self, from: data)
        else {
            self.init()
            return
        }
        self.init(marketByCode: decoded)
    }

    static var defaultFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    static func current() -> StockMarketLookup {
        StockMarketLookup(contentsOf: defaultFileURL)
    }

    func market(forCode code: String) -> StockMarket {
        marketByCode[code] ?? .tse
    }

    /// The `ex_ch` channel for one code, e.g. "otc_6488.tw".
    func exChannel(forCode code: String) -> String {
        "\(market(forCode: code).rawValue)_\(code).tw"
    }

    /// The `ex_ch` query value for several codes, e.g. "otc_6488.tw|tse_2330.tw".
    func exChannelQuery(forCodes codes: [String]) -> String {
        codes.map(exChannel(forCode:)).joined(separator: "|")
    }

    /// Writes the lookup unless the file already holds identical content.
    /// Returns whether the file was written.
    @discardableResult
    static func write(_ marketByCode: [String: StockMarket], to url: URL) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(marketByCode)
        if let existing = try? Data(contentsOf: url), existing == data {
            return false
        }
        try data.write(to: url, options: .atomic)
        return true
    }
}
