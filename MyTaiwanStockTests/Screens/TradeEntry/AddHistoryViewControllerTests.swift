import XCTest
@testable import MyTaiwanStock

@MainActor
final class AddHistoryViewControllerTests: XCTestCase {
    private func makeController() -> AddHistoryViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: AddHistoryViewController.self))
        let controller = storyboard.instantiateViewController(withIdentifier: "addRecordController") as! AddHistoryViewController
        controller.viewModel = AddHistoryViewModel(feeSettings: { FeeSettings(mode: .discount(10)) })
        controller.stockNo = "2330"
        controller.loadViewIfNeeded()
        controller.tableView.layoutIfNeeded()
        return controller
    }

    private func indexPath(of cell: UITableViewCell, in controller: AddHistoryViewController) throws -> IndexPath {
        for section in 0..<controller.tableView.numberOfSections {
            for row in 0..<controller.tableView.numberOfRows(inSection: section) {
                let path = IndexPath(row: row, section: section)
                if controller.tableView(controller.tableView, cellForRowAt: path) === cell { return path }
            }
        }
        throw NSError(domain: "Missing static cell", code: 1)
    }

    func testTaxRowsHaveZeroHeightForBuyAndBecomeVisibleForSell() throws {
        let controller = makeController()
        for cell in [controller.taxCell!, controller.taxCategoryCell!] {
            let path = try indexPath(of: cell, in: controller)
            XCTAssertEqual(controller.tableView(controller.tableView, heightForRowAt: path), 0)
            XCTAssertTrue(cell.isHidden)
        }
        let side = UISegmentedControl(items: ["買進", "賣出"])
        side.selectedSegmentIndex = 1
        controller.setSegmentControl(side)
        for cell in [controller.taxCell!, controller.taxCategoryCell!] {
            let path = try indexPath(of: cell, in: controller)
            XCTAssertGreaterThan(controller.tableView(controller.tableView, heightForRowAt: path), 0)
            XCTAssertFalse(cell.isHidden)
        }
    }

    func testEditingChangedUsesTheFinalTextAndKeepsManuallyEditedFee() {
        let controller = makeController()
        controller.priceTextField.text = "100"
        controller.priceTextField.sendActions(for: .editingChanged)
        for amount in ["1", "10", "100", "1000"] {
            controller.amountTextField.text = amount
            controller.amountTextField.sendActions(for: .editingChanged)
        }
        XCTAssertEqual(controller.feeTextField.text, "142")
        XCTAssertNotNil(controller.feeTextField.rightView as? UILabel)
        controller.feeTextField.text = "50"
        controller.feeTextField.sendActions(for: .editingChanged)
        controller.priceTextField.text = "200"
        controller.priceTextField.sendActions(for: .editingChanged)
        XCTAssertEqual(controller.feeTextField.text, "50")
        controller.feeTextField.text = ""
        controller.feeTextField.sendActions(for: .editingChanged)
        XCTAssertEqual(controller.feeTextField.text, "")
        controller.feeTextField.sendActions(for: .editingDidEnd)
        XCTAssertEqual(controller.feeTextField.text, "285")
    }

    func testCostFieldsAcceptOnlyASCIIDigits() {
        let controller = makeController()
        for field in [controller.feeTextField!, controller.taxTextField!] {
            for text in ["-5", "1.5", "abc", "１２"] {
                XCTAssertFalse(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: text))
            }
            XCTAssertTrue(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "50"))
            XCTAssertTrue(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: ""))
        }
    }

    func testMemoRowAndAccessorySegueShareTheRecordViewModel() throws {
        let controller = makeController()
        let navigation = UINavigationController(rootViewController: controller)
        let path = try indexPath(of: controller.memoCell, in: controller)
        controller.tableView(controller.tableView, didSelectRowAt: path)
        let pushed = try XCTUnwrap(navigation.topViewController as? MemoViewController)
        XCTAssertTrue(pushed.viewModel === controller.viewModel)
        let destination = controller.storyboard!.instantiateViewController(withIdentifier: "writeReasonVC") as! MemoViewController
        let segue = UIStoryboardSegue(identifier: "writeReasonSegue", source: controller, destination: destination)
        controller.prepare(for: segue, sender: controller.memoCell)
        XCTAssertTrue(destination.viewModel === controller.viewModel)
    }
}
