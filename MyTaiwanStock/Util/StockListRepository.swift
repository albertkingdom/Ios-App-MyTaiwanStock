//
//  StockListRepository.swift
//  MyTaiwanStock
//

import Foundation

/// Source of truth for the tradable stock list (listed and OTC).
///
/// Loads the local cache when it is valid and otherwise the list bundled with the app,
/// so the list is never empty. Reads and writes happen on the main actor; after
/// `replace(with:)` every later read returns the new list.
@MainActor
final class StockListRepository {
    static let shared = StockListRepository()

    private(set) var entries: [StockListEntry] = []
    private var marketByCode: [String: StockMarket] = [:]

    private let cacheURL: URL
    private let bundledURL: URL?

    init(
        cacheURL: URL = StockListRepository.defaultCacheURL,
        bundledURL: URL? = Bundle.main.url(forResource: "StockList", withExtension: "json")
    ) {
        self.cacheURL = cacheURL
        self.bundledURL = bundledURL
        reload()
    }

    nonisolated static var defaultCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("StockList.json")
    }

    /// Cache first, then the bundled fallback.
    func reload() {
        if let cached = Self.load(from: cacheURL), !cached.isEmpty {
            apply(cached)
        } else if let bundled = bundledURL.flatMap(Self.load(from:)), !bundled.isEmpty {
            apply(bundled)
        }
    }

    /// Persists the new list atomically, then makes it visible to every later read.
    func replace(with newEntries: [StockListEntry]) throws {
        let data = try JSONEncoder().encode(StockListFile(entries: newEntries))
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
        apply(newEntries)
    }

    /// Entries in the "code name" form used by the add-stock search.
    var searchStrings: [String] { entries.map(\.searchString) }

    func market(forCode code: String) -> StockMarket? { marketByCode[code] }

    func contains(code: String) -> Bool { marketByCode[code] != nil }

    private func apply(_ newEntries: [StockListEntry]) {
        entries = newEntries
        marketByCode = Dictionary(newEntries.map { ($0.code, $0.market) }, uniquingKeysWith: { first, _ in first })
    }

    private static func load(from url: URL) -> [StockListEntry]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(StockListFile.self, from: data))?.entries
    }
}
