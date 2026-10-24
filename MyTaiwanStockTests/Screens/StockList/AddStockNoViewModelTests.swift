//
//  AddStockNoViewModelTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
final class AddStockNoViewModelTests: XCTestCase {

    private func results(for text: String) -> [String] {
        let viewModel = AddStockNoViewModel()
        viewModel.searchText.send(text)
        return viewModel.filteredAddStockCellViewModelsCombine.value.map(\.stockNumberAndName)
    }

    func test_search_finds_otc_stock_by_name() {
        XCTAssertTrue(results(for: "環球").contains("6488 環球晶"))
    }

    func test_search_finds_new_etf_by_code() {
        XCTAssertTrue(results(for: "00929").contains { $0.hasPrefix("00929 ") })
    }

    func test_search_still_finds_listed_stock() {
        XCTAssertTrue(results(for: "台積電").contains("2330 台積電"))
    }
}
