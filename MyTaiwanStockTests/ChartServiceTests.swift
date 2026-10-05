//
//  ChartServiceTests.swift
//  MyTaiwanStockTests
//

import XCTest
import Charts
@testable import MyTaiwanStock

/// Candle data comes from TWSE STOCK_DAY rows:
/// [date, shares, amount, open, high, low, close, change, transactions].
final class ChartServiceTests: XCTestCase {

    private func rows(_ count: Int) -> [[String]] {
        (0..<count).map { index in
            ["115/09/\(String(format: "%02d", index + 1))", "1,000", "12,345", "100.0", "105.0", "99.0", "103.0", "+1.0", "10"]
        }
    }

    private func prepare(rowCount: Int) -> CombinedChartView {
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        ChartService(candleStickData: rows(rowCount), stockNo: "6488").prepareForCombinedChart(combinedChartView: view)
        return view
    }

    private func combinedData(_ view: CombinedChartView) -> CombinedChartData? {
        view.data as? CombinedChartData
    }

    private func candleCount(_ view: CombinedChartView) -> Int? {
        combinedData(view)?.candleData?.entryCount
    }

    private func lineEntryCounts(_ view: CombinedChartView) -> [Int] {
        (combinedData(view)?.lineData?.dataSets ?? []).map(\.entryCount)
    }

    func test_no_rows_shows_the_no_data_state() {
        let view = prepare(rowCount: 0)

        XCTAssertNil(view.data)
        XCTAssertEqual(view.noDataText, "無資料")
    }

    func test_three_rows_draw_candles_without_moving_averages() {
        let view = prepare(rowCount: 3)

        XCTAssertEqual(candleCount(view), 3)
        XCTAssertEqual(lineEntryCounts(view), [0, 0])
    }

    func test_eight_rows_draw_candles_without_moving_averages() {
        let view = prepare(rowCount: 8)

        XCTAssertEqual(candleCount(view), 8)
        XCTAssertEqual(lineEntryCounts(view), [4, 0]) // 5-day average exists from the 5th row
    }

    func test_nine_rows_have_no_ten_day_average() {
        let view = prepare(rowCount: 9)

        XCTAssertEqual(candleCount(view), 9)
        XCTAssertEqual(lineEntryCounts(view), [5, 0])
    }

    func test_ten_rows_behave_as_before() {
        let view = prepare(rowCount: 10)

        XCTAssertEqual(lineEntryCounts(view), [6, 1])
    }

    func test_rows_with_unreadable_volume_do_not_crash() {
        var broken = rows(10)
        broken[2][2] = "--"
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))

        ChartService(candleStickData: broken, stockNo: "2330").prepareForCombinedChart(combinedChartView: view)

        XCTAssertEqual(candleCount(view), 10)
    }
}
