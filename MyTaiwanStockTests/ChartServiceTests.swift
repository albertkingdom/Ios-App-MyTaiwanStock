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

    /// TWSE formats prices of 1,000 and above with a thousands separator ("2,565.00").
    func test_prices_with_thousands_separator_keep_their_value() throws {
        let row = ["115/10/07", "20,000,000", "51,000,000,000", "2,565.00", "2,585.00", "2,560.00", "2,585.00", "+20.00", "10"]
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))

        ChartService(candleStickData: [row], stockNo: "2330").prepareForCombinedChart(combinedChartView: view)

        let entry = try XCTUnwrap(combinedData(view)?.candleData?.dataSets.first?.entryForIndex(0) as? CandleChartDataEntry)
        XCTAssertEqual(entry.open, 2565.0)
        XCTAssertEqual(entry.high, 2585.0)
        XCTAssertEqual(entry.low, 2560.0)
        XCTAssertEqual(entry.close, 2585.0)
        XCTAssertEqual(try XCTUnwrap(combinedData(view)?.candleData?.getYMax(axis: .left)), 2585.0)
        XCTAssertEqual(try XCTUnwrap(combinedData(view)?.barData?.getYMax(axis: .right)), 51_000_000_000)
    }

    func test_twse_number_reads_separators_and_rejects_placeholders() {
        XCTAssertEqual("2,565.00".twseNumber, 2565.0)
        XCTAssertEqual("51,000,000,000".twseNumber, 51_000_000_000)
        XCTAssertEqual("-1,005.00".twseNumber, -1005.0)
        XCTAssertEqual("+20.00".twseNumber, 20.0)
        XCTAssertNil("--".twseNumber)
        XCTAssertNil("".twseNumber)
        XCTAssertNil("X0.00".twseNumber)
        XCTAssertNil("nan".twseNumber) // Double() accepts these, a chart must not
        XCTAssertNil("inf".twseNumber)
    }

    func test_rows_shorter_than_a_full_day_are_skipped_by_the_candle_generator() {
        let service = ChartService(candleStickData: [], stockNo: "2330")

        let data = service.generateCandleData(stockInfoForCandleStickChart: [["115/10/07", "1", "2"], rows(1)[0]], stockNo: "2330")

        XCTAssertEqual(data.entryCount, 1)
    }

    /// TWSE reports "--" for open/high/low/close on a day without trades.
    private func rowsWithNoTradeDay(count: Int, noTradeIndex: Int) -> [[String]] {
        var result = (0..<count).map { index in
            ["115/09/\(String(format: "%02d", index + 1))", "1,000", "12,345", "2,500.00", "2,520.00", "2,490.00", "2,500.00", "+1.00", "10"]
        }
        for column in 3...6 { result[noTradeIndex][column] = "--" }
        return result
    }

    func test_no_trade_day_is_not_drawn_as_a_candle_at_zero() throws {
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))

        ChartService(candleStickData: rowsWithNoTradeDay(count: 10, noTradeIndex: 4), stockNo: "2330")
            .prepareForCombinedChart(combinedChartView: view)

        let candleData = try XCTUnwrap(combinedData(view)?.candleData)
        XCTAssertEqual(candleData.entryCount, 9)
        XCTAssertEqual(candleData.getYMin(axis: .left), 2490.0)
        XCTAssertNil(candleData.dataSets.first?.entriesForXValue(4).first)
    }

    func test_moving_averages_skip_no_trade_days() throws {
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))

        ChartService(candleStickData: rowsWithNoTradeDay(count: 12, noTradeIndex: 2), stockNo: "2330")
            .prepareForCombinedChart(combinedChartView: view)

        let lines = try XCTUnwrap(combinedData(view)?.lineData?.dataSets)
        XCTAssertEqual(lines.map(\.entryCount), [7, 2]) // 11 trading days
        for line in lines {
            for index in 0..<line.entryCount {
                XCTAssertEqual(line.entryForIndex(index)?.y ?? .nan, 2500.0, accuracy: 0.001)
            }
        }
        // Averages sit on the x of the candle they end at, which is not the position once a day is skipped.
        XCTAssertEqual(lines[0].entryForIndex(0)?.x, 5)
        XCTAssertEqual(lines[1].entryForIndex(0)?.x, 10)
    }

    func test_chart_starts_at_the_latest_day_even_when_many_days_have_no_trades() {
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        var data = rowsWithNoTradeDay(count: 30, noTradeIndex: 10)
        for index in 11..<22 {
            for column in 3...6 { data[index][column] = "--" }
        }

        ChartService(candleStickData: data, stockNo: "2330").prepareForCombinedChart(combinedChartView: view)

        XCTAssertGreaterThanOrEqual(view.highestVisibleX, 29) // the latest day is x = 29, whatever the candle count
    }

    func test_all_no_trade_days_do_not_crash() {
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        var allBroken = rows(3)
        for index in allBroken.indices {
            for column in 3...6 { allBroken[index][column] = "--" }
        }

        ChartService(candleStickData: allBroken, stockNo: "2330").prepareForCombinedChart(combinedChartView: view)

        XCTAssertEqual(candleCount(view), 0)
    }

    func test_rows_with_unreadable_volume_do_not_crash() {
        var broken = rows(10)
        broken[2][2] = "--"
        let view = CombinedChartView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))

        ChartService(candleStickData: broken, stockNo: "2330").prepareForCombinedChart(combinedChartView: view)

        XCTAssertEqual(candleCount(view), 10)
    }
}
