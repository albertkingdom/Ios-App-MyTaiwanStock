//
//  TradeEditViewControllerTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
final class TradeEditViewControllerTests: XCTestCase {
    private struct Saved {
        var stockNo: String
        var price: Float?
        var amount: Int?
        var side: TradeSide
        var feeText: String?
        var taxText: String?
    }

    private var saved: Saved?

    private func makeItem(side: TradeSide = .sell, feeText: String = "6", taxText: String = "22") -> TradePreviewItem {
        var item = TradePreviewItem(
            id: UUID(), stockName: "瑞昱", stockNo: "2379",
            date: TaipeiCalendar.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30)),
            price: 757, amount: 10, side: side, tradeTypeText: "盤中零股賣出", isSupportedType: true,
            status: .importable, isSelected: true)
        item.fields = FeeTaxFields(feeText: feeText, taxText: taxText)
        return item
    }

    private func makeController(item: TradePreviewItem) -> TradeEditViewController {
        let viewModel = TradeImportViewModel(
            trades: [], resolver: StockNameResolver(entries: []), isKnownCode: { _ in true },
            store: FakeTradeImportStore(), listNames: [], currentListName: nil,
            feeSettings: FeeSettings(discount: 6))
        let controller = TradeEditViewController(
            item: item,
            estimate: { viewModel.estimate(stockNo: $0, price: $1, amount: $2, side: $3) },
            onSave: { [unowned self] stockNo, price, amount, _, side, feeText, taxText in
                saved = Saved(stockNo: stockNo, price: price, amount: amount, side: side, feeText: feeText, taxText: taxText)
            })
        controller.loadViewIfNeeded()
        controller.tableView.layoutIfNeeded()
        return controller
    }

    /// The control of the row with this title.
    private func control(_ title: String, in controller: TradeEditViewController) throws -> UIView {
        for row in 0..<controller.tableView(controller.tableView, numberOfRowsInSection: 0) {
            let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: row, section: 0))
            if (cell.contentConfiguration as? UIListContentConfiguration)?.text == title {
                return try XCTUnwrap(cell.accessoryView)
            }
        }
        throw XCTSkip("no row titled \(title)")
    }

    private func field(_ title: String, in controller: TradeEditViewController) throws -> UITextField {
        try XCTUnwrap(control(title, in: controller) as? UITextField)
    }

    private func rowCount(_ controller: TradeEditViewController) -> Int {
        controller.tableView(controller.tableView, numberOfRowsInSection: 0)
    }

    private func type(_ text: String, into field: UITextField) {
        field.text = text
        field.sendActions(for: .editingChanged)
    }

    private func tapSave(_ controller: TradeEditViewController) throws {
        let button = try XCTUnwrap(controller.navigationItem.rightBarButtonItem)
        _ = (button.target as? NSObject)?.perform(try XCTUnwrap(button.action))
    }

    func test_a_sell_shows_the_estimates_of_the_fee_and_the_tax() throws {
        let controller = makeController(item: makeItem())

        XCTAssertEqual(try field("手續費（元）", in: controller).text, "6")
        XCTAssertEqual(try field("證交稅（元）", in: controller).text, "22")
    }

    func test_a_buy_has_no_tax_row_and_a_sell_has() throws {
        let controller = makeController(item: makeItem(side: .buy, taxText: "0"))
        let rowsOfABuy = rowCount(controller)
        let side = try XCTUnwrap(control("買賣", in: controller) as? UISegmentedControl)

        side.selectedSegmentIndex = 1
        side.sendActions(for: .valueChanged)

        XCTAssertEqual(rowCount(controller), rowsOfABuy + 1)
        XCTAssertEqual(try field("證交稅（元）", in: controller).text, "22")
    }

    func test_changing_the_price_updates_a_fee_the_user_did_not_type() throws {
        let controller = makeController(item: makeItem())

        try type("800", into: field("價格", in: controller))

        XCTAssertEqual(try field("手續費（元）", in: controller).text, "6")
        XCTAssertEqual(try field("證交稅（元）", in: controller).text, "24")
        try type("1000", into: field("股數", in: controller))
        XCTAssertEqual(try field("手續費（元）", in: controller).text, "684")
    }

    func test_a_fee_the_user_typed_is_kept_when_the_price_changes() throws {
        let controller = makeController(item: makeItem())

        try type("3", into: field("手續費（元）", in: controller))
        try type("800", into: field("價格", in: controller))

        XCTAssertEqual(try field("手續費（元）", in: controller).text, "3")
    }

    func test_leaving_a_cleared_fee_shows_the_estimate_again() throws {
        let controller = makeController(item: makeItem())
        let fee = try field("手續費（元）", in: controller)
        type("3", into: fee)

        type("", into: fee)
        fee.sendActions(for: .editingDidEnd)

        XCTAssertEqual(fee.text, "6")
        try tapSave(controller)
        XCTAssertNil(saved?.feeText)
    }

    func test_saving_without_touching_the_fee_and_the_tax_leaves_them_to_the_estimate() throws {
        let controller = makeController(item: makeItem())

        try tapSave(controller)

        XCTAssertNil(saved?.feeText)
        XCTAssertNil(saved?.taxText)
    }

    func test_saving_passes_the_typed_fee_and_tax() throws {
        let controller = makeController(item: makeItem())

        try type("3", into: field("手續費（元）", in: controller))
        try type("30", into: field("證交稅（元）", in: controller))
        try tapSave(controller)

        XCTAssertEqual(saved?.feeText, "3")
        XCTAssertEqual(saved?.taxText, "30")
        XCTAssertEqual(saved?.side, .sell)
    }

    func test_a_buy_passes_no_tax() throws {
        let controller = makeController(item: makeItem(side: .buy, taxText: "0"))

        try tapSave(controller)

        XCTAssertNil(saved?.taxText)
    }

    func test_a_value_the_trade_cannot_be_saved_with_is_shown_in_red() throws {
        let controller = makeController(item: makeItem())
        let fee = try field("手續費（元）", in: controller)

        type("-5", into: fee)
        XCTAssertEqual(fee.textColor, .systemRed)

        type("5", into: fee)
        XCTAssertEqual(fee.textColor, .label)
    }

    func test_an_invalid_value_from_an_earlier_edit_is_red_when_the_editor_opens() throws {
        var item = makeItem()
        var fields = FeeTaxFields()
        fields.editFee("-5")
        item.fields = fields

        let controller = makeController(item: item)

        XCTAssertEqual(try field("手續費（元）", in: controller).textColor, .systemRed)
    }
}
