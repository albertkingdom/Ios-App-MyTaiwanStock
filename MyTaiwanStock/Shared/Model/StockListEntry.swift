//
//  StockListEntry.swift
//  MyTaiwanStock
//

import Foundation

enum StockMarket: String, Codable {
    /// Listed on the Taiwan Stock Exchange (including ETFs); quoted with the `tse_` prefix.
    case tse
    /// Traded over the counter on the Taipei Exchange; quoted with the `otc_` prefix.
    case otc
}

struct StockListEntry: Codable, Equatable {
    let code: String
    let name: String
    let market: StockMarket

    /// The "code name" form used by the add-stock search, e.g. "6488 環球晶".
    var searchString: String { "\(code) \(name)" }
}

/// On-disk shape of both the bundled fallback list and the cached list.
struct StockListFile: Codable, Equatable {
    let entries: [StockListEntry]
}
