//
//  TradeImportPreviewViewControllerTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
final class TradeImportPreviewViewControllerTests: XCTestCase {
    private let entries = [StockListEntry(code: "2379", name: "瑞昱", market: .tse)]

    private func makeViewModel(price: Float? = 757) -> TradeImportViewModel {
        let trade = ParsedTrade(
            stockName: "瑞昱", date: TaipeiCalendar.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30)),
            price: price, amount: 10, side: .sell, tradeTypeText: "盤中零股賣出", isSupportedType: true)
        return TradeImportViewModel(
            trades: [trade], resolver: StockNameResolver(entries: entries), isKnownCode: { _ in true },
            store: FakeTradeImportStore(), listNames: [], currentListName: nil,
            feeSettings: FeeSettings(mode: .discount(6)))
    }

    private func makeNavigation(_ viewModel: TradeImportViewModel) -> (UINavigationController, TradeImportPreviewViewController) {
        let controller = TradeImportPreviewViewController(viewModel: viewModel, onImported: {})
        let navigation = UINavigationController(rootViewController: controller)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        controller.view.layoutIfNeeded()
        return (navigation, controller)
    }

    private func descendants(of view: UIView) -> [UIView] { view.subviews + view.subviews.flatMap(descendants) }

    private func tradeCell(in controller: UIViewController) throws -> UITableViewCell {
        let table = try XCTUnwrap(descendants(of: controller.view).compactMap { $0 as? UITableView }.first)
        return table.dataSource!.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1))
    }

    private func secondaryText(of cell: UITableViewCell) -> String? {
        (cell.contentConfiguration as? UIListContentConfiguration)?.secondaryText
    }

    func test_a_row_shows_the_estimated_fee_and_tax_on_its_second_line() throws {
        let (_, controller) = makeNavigation(makeViewModel())

        let text = try XCTUnwrap(secondaryText(of: tradeCell(in: controller)))

        XCTAssertTrue(text.hasSuffix("手續費 6 ・ 稅 22"), text)
    }

    func test_a_row_without_an_estimate_asks_for_the_values() throws {
        let (_, controller) = makeNavigation(makeViewModel(price: nil))

        let text = try XCTUnwrap(secondaryText(of: tradeCell(in: controller)))

        XCTAssertTrue(text.hasSuffix("手續費？ ・ 稅？"), text)
    }

    /// Saving the editor applies the inputs first and the typed fee last, so the fee survives the new price
    /// while the tax the user left alone follows it.
    func test_saving_the_editor_keeps_the_typed_fee_and_re_estimates_the_rest() throws {
        let viewModel = makeViewModel()
        let (navigation, controller) = makeNavigation(viewModel)
        let info = try XCTUnwrap(
            descendants(of: try tradeCell(in: controller).accessoryView!).compactMap { $0 as? UIButton }.first)

        info.sendActions(for: .touchUpInside)
        let editor = try XCTUnwrap(navigation.topViewController as? TradeEditViewController)
        editor.loadViewIfNeeded()

        func field(_ title: String) throws -> UITextField {
            for row in 0..<editor.tableView(editor.tableView, numberOfRowsInSection: 0) {
                let cell = editor.tableView(editor.tableView, cellForRowAt: IndexPath(row: row, section: 0))
                if (cell.contentConfiguration as? UIListContentConfiguration)?.text == title {
                    return try XCTUnwrap(cell.accessoryView as? UITextField)
                }
            }
            throw XCTSkip("no row titled \(title)")
        }
        let fee = try field("手續費（元）")
        fee.text = "3"
        fee.sendActions(for: .editingChanged)
        let price = try field("價格")
        price.text = "800"
        price.sendActions(for: .editingChanged)
        let save = try XCTUnwrap(editor.navigationItem.rightBarButtonItem)
        _ = (save.target as? NSObject)?.perform(try XCTUnwrap(save.action))

        XCTAssertEqual(viewModel.items[0].price, 800)
        XCTAssertEqual(viewModel.items[0].feeText, "3")
        XCTAssertEqual(viewModel.items[0].taxText, "24")
        XCTAssertTrue(viewModel.items[0].fields.feeIsManual)
        XCTAssertFalse(viewModel.items[0].fields.taxIsManual)
    }
}
