//
//  StockListRefresher.swift
//  MyTaiwanStock
//

import Foundation

/// Downloads the raw open-data payloads. Kept behind a protocol so tests can inject results.
protocol StockListFetching: Sendable {
    func fetchTWSE() async throws -> Data
    func fetchOTC() async throws -> Data
}

struct URLSessionStockListFetcher: StockListFetching {
    static let twseURL = URL(string: "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL")!
    static let otcURL = URL(string: "https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes")!

    func fetchTWSE() async throws -> Data { try await fetch(Self.twseURL) }
    func fetchOTC() async throws -> Data { try await fetch(Self.otcURL) }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

/// Refreshes the stock list from the official open data when it is stale.
///
/// A refresh starts when no refreshed list is cached or the last successful refresh is at
/// least 7 days old. The two markets are judged independently: a market is adopted only
/// when it was fetched and decoded successfully and has at least 80 percent of the entries
/// that market currently has. Anything else keeps that market's existing entries.
@MainActor
final class StockListRefresher {
    enum MarketOutcome: Equatable {
        case updated
        case skipped
        case keptOldData
    }

    struct Result: Equatable {
        var tse: MarketOutcome
        var otc: MarketOutcome

        static let skipped = Result(tse: .skipped, otc: .skipped)
    }

    static let shared = StockListRefresher(repository: .shared)

    static let lastRefreshKey = "StockListRefresher.lastRefreshDate"
    static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    static let minimumRatio = 0.8

    private let repository: StockListRepository
    private let fetcher: StockListFetching
    private let userDefaults: UserDefaults
    private let now: () -> Date
    private var inFlight: Task<Result, Never>?

    init(
        repository: StockListRepository,
        fetcher: StockListFetching = URLSessionStockListFetcher(),
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.fetcher = fetcher
        self.userDefaults = userDefaults
        self.now = now
    }

    /// Runs a refresh when one is due. Only one refresh runs at a time: a call made while
    /// another is in progress waits for and returns that refresh's result.
    @discardableResult
    func refreshIfNeeded() async -> Result {
        if let inFlight {
            return await inFlight.value
        }
        guard isRefreshDue else { return .skipped }

        let task = Task { () -> Result in
            let result = await self.performRefresh()
            self.inFlight = nil
            return result
        }
        inFlight = task
        return await task.value
    }

    private var isRefreshDue: Bool {
        guard repository.hasCache,
              let last = userDefaults.object(forKey: Self.lastRefreshKey) as? Date
        else { return true }
        return now().timeIntervalSince(last) >= Self.refreshInterval
    }

    private func performRefresh() async -> Result {
        let currentTSE = repository.entries.filter { $0.market == .tse }
        let currentOTC = repository.entries.filter { $0.market == .otc }

        async let fetchedTSE = loadMarket { try StockListParser.parseTWSE(try await self.fetcher.fetchTWSE()) }
        async let fetchedOTC = loadMarket { try StockListParser.parseOTC(try await self.fetcher.fetchOTC()) }
        let (tseEntries, otcEntries) = await (fetchedTSE, fetchedOTC)

        let tseAdopted = Self.isAcceptable(fetched: tseEntries, currentCount: currentTSE.count)
        let otcAdopted = Self.isAcceptable(fetched: otcEntries, currentCount: currentOTC.count)
        var result = Result(
            tse: tseAdopted ? .updated : .keptOldData,
            otc: otcAdopted ? .updated : .keptOldData)

        guard tseAdopted || otcAdopted else { return result }

        let merged = StockListParser.merge(
            tse: tseAdopted ? tseEntries! : currentTSE,
            otc: otcAdopted ? otcEntries! : currentOTC)
        do {
            try repository.replace(with: merged)
            userDefaults.set(now(), forKey: Self.lastRefreshKey)
            print("stock list refreshed: tse=\(merged.filter { $0.market == .tse }.count) otc=\(merged.filter { $0.market == .otc }.count)")
        } catch {
            print("stock list refresh could not be saved: \(error)")
            result = Result(tse: .keptOldData, otc: .keptOldData)
        }
        return result
    }

    /// Fetching and decoding run off the main actor so a multi-megabyte payload never blocks the UI.
    private nonisolated func loadMarket(_ work: @Sendable () async throws -> [StockListEntry]) async -> [StockListEntry]? {
        do {
            return try await work()
        } catch {
            print("stock list fetch failed: \(error)")
            return nil
        }
    }

    private static func isAcceptable(fetched: [StockListEntry]?, currentCount: Int) -> Bool {
        guard let fetched, !fetched.isEmpty else { return false }
        return Double(fetched.count) >= Double(currentCount) * minimumRatio
    }
}
