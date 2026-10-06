//
//  StockListParser.swift
//  MyTaiwanStock
//

import Foundation

/// Turns the official open-data payloads into `StockListEntry` values.
/// The OTC filter must stay identical to `keep_otc` in scripts/generate_stock_list.py.
enum StockListParser {
    // Only these two fields are decoded; the Taipei Exchange payload is ~4.6 MB and mostly warrants.
    private struct TWSERow: Decodable {
        let Code: String
        let Name: String
    }

    private struct OTCRow: Decodable {
        let SecuritiesCompanyCode: String
        let CompanyName: String
    }

    static func parseTWSE(_ data: Data) throws -> [StockListEntry] {
        try JSONDecoder().decode([TWSERow].self, from: data).compactMap { row in
            makeEntry(code: row.Code, name: row.Name, market: .tse)
        }
    }

    static func parseOTC(_ data: Data) throws -> [StockListEntry] {
        try JSONDecoder().decode([OTCRow].self, from: data).compactMap { row in
            let code = row.SecuritiesCompanyCode.trimmingCharacters(in: .whitespaces)
            guard isKeptOTCCode(code) else { return nil }
            return makeEntry(code: code, name: row.CompanyName, market: .otc)
        }
    }

    /// Keeps stocks (up to 5 characters) and ETFs (start with "00"); drops warrants,
    /// which are 6-character codes starting with 70 to 73.
    static func isKeptOTCCode(_ code: String) -> Bool {
        code.count <= 5 || code.hasPrefix("00")
    }

    /// Combines both markets; a code present in both keeps the TWSE entry.
    static func merge(tse: [StockListEntry], otc: [StockListEntry]) -> [StockListEntry] {
        let tseCodes = Set(tse.map(\.code))
        let otcOnly = otc.filter { !tseCodes.contains($0.code) }
        return (tse + otcOnly).sorted { $0.code < $1.code }
    }

    private static func makeEntry(code: String, name: String, market: StockMarket) -> StockListEntry? {
        let code = code.trimmingCharacters(in: .whitespaces)
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !name.isEmpty else { return nil }
        return StockListEntry(code: code, name: name, market: market)
    }
}
