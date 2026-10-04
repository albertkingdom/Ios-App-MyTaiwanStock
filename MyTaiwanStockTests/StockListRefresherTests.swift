//
//  StockListRefresherTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

private final class FakeStockListFetcher: StockListFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _tseCalls = 0
    private var _otcCalls = 0
    var tse: Swift.Result<Data, Error> = .success(Data("[]".utf8))
    var otc: Swift.Result<Data, Error> = .success(Data("[]".utf8))
    /// When set, every fetch waits until the gate opens.
    var gate: Gate?

    var tseCalls: Int { lock.withLock { _tseCalls } }
    var otcCalls: Int { lock.withLock { _otcCalls } }

    func fetchTWSE() async throws -> Data {
        lock.withLock { _tseCalls += 1 }
        await gate?.wait()
        return try tse.get()
    }

    func fetchOTC() async throws -> Data {
        lock.withLock { _otcCalls += 1 }
        await gate?.wait()
        return try otc.get()
    }
}

private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

@MainActor
final class StockListRefresherTests: XCTestCase {

    private var directory: URL!
    private var repository: StockListRepository!
    private var defaults: UserDefaults!
    private var fetcher: FakeStockListFetcher!
    private var currentDate = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private let suiteName = "StockListRefresherTests"

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        fetcher = FakeStockListFetcher()

        // Bundled list: 1380 listed + 1007 OTC entries, like the real data.
        let bundledURL = directory.appendingPathComponent("bundled.json")
        try JSONEncoder().encode(StockListFile(entries: Self.entries(tse: 1380, otc: 1007))).write(to: bundledURL)
        repository = StockListRepository(
            cacheURL: directory.appendingPathComponent("cache/StockList.json"),
            bundledURL: bundledURL)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private static func entries(tse: Int, otc: Int) -> [StockListEntry] {
        (0..<tse).map { StockListEntry(code: String(format: "%04d", 1000 + $0), name: "上市\($0)", market: .tse) }
            + (0..<otc).map { StockListEntry(code: String(format: "%04d", 6000 + $0), name: "上櫃\($0)", market: .otc) }
    }

    private func twseJSON(count: Int) -> Data {
        let rows = (0..<count).map { #"{"Code":"\#(String(format: "%04d", 1000 + $0))","Name":"新上市\#($0)","TradeVolume":"1"}"# }
        return Data("[\(rows.joined(separator: ","))]".utf8)
    }

    private func otcJSON(count: Int) -> Data {
        let rows = (0..<count).map { #"{"SecuritiesCompanyCode":"\#(String(format: "%04d", 6000 + $0))","CompanyName":"新上櫃\#($0)","Close":"1"}"# }
        return Data("[\(rows.joined(separator: ","))]".utf8)
    }

    private func makeRefresher() -> StockListRefresher {
        StockListRefresher(repository: repository, fetcher: fetcher, userDefaults: defaults, now: { [unowned self] in currentDate })
    }

    /// Marks a successful refresh `daysAgo` days before `currentDate`, and creates the cache file.
    private func seedLastRefresh(daysAgo: Double) throws {
        try repository.replace(with: repository.entries)
        defaults.set(currentDate.addingTimeInterval(-daysAgo * day), forKey: StockListRefresher.lastRefreshKey)
    }

    // MARK: refresh decision

    func test_six_days_after_last_refresh_does_not_refresh() async throws {
        try seedLastRefresh(daysAgo: 6)

        let result = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(result, .init(tse: .skipped, otc: .skipped))
        XCTAssertEqual(fetcher.tseCalls + fetcher.otcCalls, 0)
    }

    func test_seven_days_after_last_refresh_refreshes() async throws {
        try seedLastRefresh(daysAgo: 7)
        fetcher.tse = .success(twseJSON(count: 1400))
        fetcher.otc = .success(otcJSON(count: 1010))

        let result = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(result, .init(tse: .updated, otc: .updated))
        XCTAssertEqual(repository.entries.filter { $0.market == .tse }.count, 1400)
        XCTAssertEqual(repository.entries.filter { $0.market == .otc }.count, 1010)
    }

    func test_no_cache_refreshes_immediately_even_if_recently_refreshed() async {
        defaults.set(currentDate, forKey: StockListRefresher.lastRefreshKey)
        fetcher.tse = .success(twseJSON(count: 1380))
        fetcher.otc = .success(otcJSON(count: 1007))

        let result = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(result, .init(tse: .updated, otc: .updated))
    }

    func test_successful_refresh_records_time_so_next_check_is_skipped() async {
        fetcher.tse = .success(twseJSON(count: 1380))
        fetcher.otc = .success(otcJSON(count: 1007))
        let refresher = makeRefresher()

        _ = await refresher.refreshIfNeeded()
        let second = await refresher.refreshIfNeeded()

        XCTAssertEqual(second, .init(tse: .skipped, otc: .skipped))
        XCTAssertEqual(fetcher.tseCalls, 1)
    }

    // MARK: 80 percent guard

    func test_otc_below_80_percent_is_rejected_but_tse_still_updates() async {
        fetcher.tse = .success(twseJSON(count: 1390))
        fetcher.otc = .success(otcJSON(count: 700)) // below 1007 * 0.8 = 805.6

        let result = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(result, .init(tse: .updated, otc: .keptOldData))
        XCTAssertEqual(repository.entries.filter { $0.market == .tse }.count, 1390)
        XCTAssertEqual(repository.entries.filter { $0.market == .otc }.count, 1007)
    }

    func test_guard_boundaries() async {
        fetcher.tse = .success(twseJSON(count: 1380))
        fetcher.otc = .success(otcJSON(count: 806))

        let adopted = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(adopted.otc, .updated)
    }

    func test_empty_payload_is_rejected() async {
        fetcher.tse = .success(Data("[]".utf8))
        fetcher.otc = .success(Data("[]".utf8))

        let result = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(result, .init(tse: .keptOldData, otc: .keptOldData))
        XCTAssertNil(defaults.object(forKey: StockListRefresher.lastRefreshKey))
    }

    // MARK: failures

    func test_network_and_decoding_errors_keep_old_data_and_do_not_record_time() async {
        fetcher.tse = .failure(URLError(.timedOut))
        fetcher.otc = .success(Data("not json".utf8))
        let before = repository.entries

        let result = await makeRefresher().refreshIfNeeded()

        XCTAssertEqual(result, .init(tse: .keptOldData, otc: .keptOldData))
        XCTAssertEqual(repository.entries, before)
        XCTAssertNil(defaults.object(forKey: StockListRefresher.lastRefreshKey))
        XCTAssertFalse(repository.hasCache)
    }

    // MARK: single flight

    func test_two_concurrent_requests_download_each_source_once() async {
        let gate = Gate()
        fetcher.gate = gate
        fetcher.tse = .success(twseJSON(count: 1380))
        fetcher.otc = .success(otcJSON(count: 1007))
        let refresher = makeRefresher()

        async let first = refresher.refreshIfNeeded()
        async let second = refresher.refreshIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await gate.open()
        _ = await (first, second)

        XCTAssertEqual(fetcher.tseCalls, 1)
        XCTAssertEqual(fetcher.otcCalls, 1)
    }
}
