//
//  FeeSettingsViewControllerTests.swift
//  MyTaiwanStockTests
//

import UIKit
import XCTest
@testable import MyTaiwanStock

final class FeeSettingsViewControllerTests: XCTestCase {
    private var messages: [String] = []

    private func makeDefaults() -> UserDefaults {
        let name = "FeeSettingsViewControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    /// The page is pushed onto a navigation controller so that save can pop it.
    private func makePage(defaults: UserDefaults) -> (UINavigationController, FeeSettingsViewController) {
        let nav = UINavigationController(rootViewController: UIViewController())
        let page = FeeSettingsViewController(userDefaults: defaults)
        page.showError = { [unowned self] in self.messages.append($0) }
        nav.pushViewController(page, animated: false)
        page.loadViewIfNeeded()
        return (nav, page)
    }

    private func seed(_ defaults: UserDefaults) {
        FeeSettings.save(
            FeeSettings(mode: .discount(6), wholeLotMinimumFee: 20, oddLotMinimumFee: 1), userDefaults: defaults)
    }

    func test_showsDefaultsWhenNothingIsSaved() {
        let (_, page) = makePage(defaults: makeDefaults())

        XCTAssertEqual(page.discountField.text, "10")
        XCTAssertEqual(page.wholeLotMinimumField.text, "20")
        XCTAssertEqual(page.oddLotMinimumField.text, "1")
    }

    func test_showsStoredValues() {
        let defaults = makeDefaults()
        FeeSettings.save(
            FeeSettings(mode: .discount(2.8), wholeLotMinimumFee: 30, oddLotMinimumFee: 5), userDefaults: defaults)

        let (_, page) = makePage(defaults: defaults)

        XCTAssertEqual(page.discountField.text, "2.8")
        XCTAssertEqual(page.wholeLotMinimumField.text, "30")
        XCTAssertEqual(page.oddLotMinimumField.text, "5")
    }

    func test_save_validInput_writesThreeKeysLeavesFeeModeAndReturns() {
        let defaults = makeDefaults()
        defaults.set("fixedAmount", forKey: "feeMode")
        let (nav, page) = makePage(defaults: defaults)
        page.discountField.text = "2.8"
        page.wholeLotMinimumField.text = "30"
        page.oddLotMinimumField.text = "5"

        page.save()

        XCTAssertEqual(defaults.double(forKey: "feeDiscount"), 2.8, accuracy: 0.0001)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumWholeLot"), 30)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumOddLot"), 5)
        XCTAssertEqual(defaults.string(forKey: "feeMode"), "fixedAmount")
        XCTAssertEqual(nav.viewControllers.count, 1)
        XCTAssertEqual(messages, [])
    }

    func test_save_invalidDiscount_showsErrorAndWritesNothing() {
        let defaults = makeDefaults()
        seed(defaults)
        let (nav, page) = makePage(defaults: defaults)
        page.discountField.text = "11"
        page.wholeLotMinimumField.text = "30"
        page.oddLotMinimumField.text = "5"

        page.save()

        XCTAssertEqual(messages, [FeeSettingsError.invalidDiscount.localizedDescription])
        XCTAssertEqual(defaults.double(forKey: "feeDiscount"), 6, accuracy: 0.0001)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumWholeLot"), 20)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumOddLot"), 1)
        XCTAssertEqual(nav.viewControllers.count, 2)
        XCTAssertEqual(page.discountField.text, "11")
    }

    func test_save_invalidWholeLotMinimum_showsErrorAndKeepsStoredValues() {
        let defaults = makeDefaults()
        seed(defaults)
        let (nav, page) = makePage(defaults: defaults)
        page.discountField.text = "2.8"
        page.wholeLotMinimumField.text = "20.5"
        page.oddLotMinimumField.text = "5"

        page.save()

        XCTAssertEqual(messages, [FeeSettingsError.invalidWholeLotMinimumFee.localizedDescription])
        XCTAssertEqual(defaults.double(forKey: "feeDiscount"), 6, accuracy: 0.0001)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumWholeLot"), 20)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumOddLot"), 1)
        XCTAssertEqual(nav.viewControllers.count, 2)
        XCTAssertEqual(page.discountField.text, "2.8")
        XCTAssertEqual(page.wholeLotMinimumField.text, "20.5")
    }

    func test_save_invalidOddLotMinimum_showsErrorAndWritesNothingElse() {
        let defaults = makeDefaults()
        seed(defaults)
        let (nav, page) = makePage(defaults: defaults)
        page.discountField.text = "2.8"
        page.wholeLotMinimumField.text = "30"
        page.oddLotMinimumField.text = "abc"

        page.save()

        XCTAssertEqual(messages, [FeeSettingsError.invalidOddLotMinimumFee.localizedDescription])
        XCTAssertEqual(defaults.double(forKey: "feeDiscount"), 6, accuracy: 0.0001)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumWholeLot"), 20)
        XCTAssertEqual(defaults.integer(forKey: "feeMinimumOddLot"), 1)
        XCTAssertEqual(nav.viewControllers.count, 2)
        XCTAssertEqual(page.discountField.text, "2.8")
        XCTAssertEqual(page.wholeLotMinimumField.text, "30")
        XCTAssertEqual(page.oddLotMinimumField.text, "abc")
    }

    func test_save_invalidValuesTogether_reportsDiscountFirst() {
        let defaults = makeDefaults()
        seed(defaults)
        let (_, page) = makePage(defaults: defaults)
        page.discountField.text = "0"
        page.wholeLotMinimumField.text = "-1"
        page.oddLotMinimumField.text = "-1"

        page.save()

        XCTAssertEqual(messages, [FeeSettingsError.invalidDiscount.localizedDescription])
        XCTAssertEqual(defaults.double(forKey: "feeDiscount"), 6, accuracy: 0.0001)
    }
}
