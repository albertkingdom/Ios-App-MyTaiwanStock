//
//  StockListRepositoryTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
final class StockListRepositoryTests: XCTestCase {

    private var directory: URL!
    private var cacheURL: URL!
    private var bundledURL: URL!
    private var lookupURL: URL!

    private let bundledEntries = [StockListEntry(code: "2330", name: "台積電", market: .tse)]
    private let cachedEntries = [
        StockListEntry(code: "9999", name: "快取股", market: .tse),
        StockListEntry(code: "6488", name: "環球晶", market: .otc),
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("cache/StockList.json")
        bundledURL = directory.appendingPathComponent("bundled.json")
        lookupURL = directory.appendingPathComponent(StockMarketLookup.fileName)
        try write(bundledEntries, to: bundledURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func write(_ entries: [StockListEntry], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(StockListFile(entries: entries)).write(to: url)
    }

    private func makeRepository() -> StockListRepository {
        StockListRepository(cacheURL: cacheURL, bundledURL: bundledURL, marketLookupURL: lookupURL)
    }

    func test_valid_cache_is_used() throws {
        try write(cachedEntries, to: cacheURL)

        XCTAssertEqual(makeRepository().entries, cachedEntries)
    }

    func test_missing_cache_falls_back_to_bundled_list() {
        XCTAssertEqual(makeRepository().entries, bundledEntries)
    }

    func test_corrupted_cache_falls_back_to_bundled_list() throws {
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: cacheURL)

        XCTAssertEqual(makeRepository().entries, bundledEntries)
    }

    func test_empty_cache_falls_back_to_bundled_list() throws {
        try write([], to: cacheURL)

        let repository = makeRepository()

        XCTAssertEqual(repository.entries, bundledEntries)
        XCTAssertFalse(repository.entries.isEmpty)
    }

    func test_search_strings_market_and_contains() throws {
        try write(cachedEntries, to: cacheURL)
        let repository = makeRepository()

        XCTAssertTrue(repository.searchStrings.contains("6488 環球晶"))
        XCTAssertEqual(repository.market(forCode: "6488"), .otc)
        XCTAssertEqual(repository.market(forCode: "9999"), .tse)
        XCTAssertNil(repository.market(forCode: "0000"))
        XCTAssertTrue(repository.contains(code: "6488"))
        XCTAssertFalse(repository.contains(code: "23"))
    }

    func test_replace_updates_memory_and_persists_to_cache() throws {
        let repository = makeRepository()

        try repository.replace(with: cachedEntries)

        XCTAssertEqual(repository.entries, cachedEntries)
        XCTAssertEqual(makeRepository().entries, cachedEntries)
    }

    func test_real_bundled_list_contains_otc_stock_and_new_etf() {
        let repository = StockListRepository(cacheURL: cacheURL, marketLookupURL: lookupURL)

        XCTAssertTrue(repository.searchStrings.contains("6488 環球晶"))
        XCTAssertEqual(repository.market(forCode: "6488"), .otc)
        XCTAssertTrue(repository.contains(code: "00929"))
        XCTAssertEqual(repository.market(forCode: "2330"), .tse)
    }

    // MARK: market lookup shared with the widget

    func test_loading_writes_the_market_of_every_entry_for_the_widget() throws {
        try write(cachedEntries, to: cacheURL)

        _ = makeRepository()

        let lookup = StockMarketLookup(contentsOf: lookupURL)
        XCTAssertEqual(lookup.market(forCode: "6488"), .otc)
        XCTAssertEqual(lookup.market(forCode: "9999"), .tse)
    }

    func test_bundled_fallback_also_writes_the_lookup() {
        _ = makeRepository()

        XCTAssertEqual(StockMarketLookup(contentsOf: lookupURL).market(forCode: "2330"), .tse)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lookupURL.path))
    }

    func test_replace_updates_the_lookup() throws {
        let repository = makeRepository()

        try repository.replace(with: cachedEntries)

        XCTAssertEqual(StockMarketLookup(contentsOf: lookupURL).market(forCode: "6488"), .otc)
    }
}
