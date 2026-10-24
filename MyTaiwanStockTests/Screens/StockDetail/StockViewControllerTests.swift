//
//  StockViewControllerTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

@MainActor
final class StockViewControllerTests: XCTestCase {
    private func makeController() -> (StockViewController, StockDetailViewModel) {
        let viewModel = StockDetailViewModel(stockNo: "0050", currentStockPrice: "105", repository: MockNetworkService())
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: StockViewController.self))
        let controller = storyboard.instantiateViewController(withIdentifier: "stockViewController") as! StockViewController
        controller.configure(with: viewModel)
        controller.stockName = "元大台灣50"
        controller.stockPrice = "105"
        controller.timeString = "10-24"
        controller.loadViewIfNeeded()
        layout(controller)
        return (controller, viewModel)
    }

    private func layout(_ controller: StockViewController) {
        controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    private func buy(fee: Int32?) -> MyTaiwanStock.InvestHistory {
        HistoryFixtures.history(side: 0, shares: 1000, price: 100, fee: fee)
    }

    func test_the_note_shows_only_while_a_buy_has_no_fee_and_the_header_makes_room_for_it() {
        let (controller, viewModel) = makeController()
        XCTAssertTrue(controller.feeNoteLabel.isHidden)
        let heightWithoutNote = controller.containerTableView.tableHeaderView!.frame.height

        viewModel.coreDataObjectsCombine = [buy(fee: nil)]
        layout(controller)

        XCTAssertFalse(controller.feeNoteLabel.isHidden)
        XCTAssertGreaterThan(controller.containerTableView.tableHeaderView!.frame.height, heightWithoutNote)

        viewModel.coreDataObjectsCombine = [buy(fee: 142)]
        layout(controller)

        XCTAssertTrue(controller.feeNoteLabel.isHidden)
        XCTAssertEqual(controller.containerTableView.tableHeaderView!.frame.height, heightWithoutNote, accuracy: 0.5)
    }

    func test_the_note_and_the_title_use_the_localized_texts() {
        let (controller, _) = makeController()

        XCTAssertEqual(controller.feeNoteLabel.text, "detailVC_fee_note".localized)
        XCTAssertEqual(controller.avgBuyPriceTitleLabel.text, "detailVC_avg_buy_title".localized)
        // A missing catalog entry returns the key itself, which would make the comparisons above pass anyway.
        for key in ["detailVC_fee_note", "detailVC_avg_buy_title", "detailVC_fee_tax_format"] {
            XCTAssertNotEqual(key.localized, key, "\(key) is missing from Localizable.xcstrings")
        }
    }

    func test_the_rows_size_themselves_instead_of_using_a_fixed_height() {
        let (controller, _) = makeController()

        XCTAssertEqual(controller.containerTableView.rowHeight, UITableView.automaticDimension)
        XCTAssertFalse(controller.responds(to: #selector(UITableViewDelegate.tableView(_:heightForRowAt:))))
    }
}
