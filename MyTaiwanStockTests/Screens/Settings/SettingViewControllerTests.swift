//
//  SettingViewControllerTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class SettingViewControllerTests: XCTestCase {
    private var originalSyncPreference: SyncPreference!

    override func setUp() {
        super.setUp()
        originalSyncPreference = UserPreferences.shared.syncPreference
    }

    override func tearDown() {
        UserPreferences.shared.syncPreference = originalSyncPreference
        super.tearDown()
    }

    // MARK: - iCloud backup toggle enabled but device not signed into iCloud

    func test_section0FooterText_showsRiskWarning_whenToggleOnButICloudUnavailable() {
        UserPreferences.shared.syncPreference = .iCloud
        let vc = SettingViewController()
        vc.iCloudAvailabilityChecking = FakeICloudAvailabilityChecker(available: false)

        let text = vc.section0FooterText()

        XCTAssertTrue(
            text.contains("資料將無法復原"),
            "toggle being on should not suppress the risk warning when iCloud is actually unavailable"
        )
    }

    func test_section0FooterText_distinguishesToggleOffFromToggleOnButUnavailable() {
        UserPreferences.shared.syncPreference = .local
        let toggleOffVC = SettingViewController()
        toggleOffVC.iCloudAvailabilityChecking = FakeICloudAvailabilityChecker(available: false)
        let toggleOffText = toggleOffVC.section0FooterText()

        UserPreferences.shared.syncPreference = .iCloud
        let toggleOnUnavailableVC = SettingViewController()
        toggleOnUnavailableVC.iCloudAvailabilityChecking = FakeICloudAvailabilityChecker(available: false)
        let toggleOnUnavailableText = toggleOnUnavailableVC.section0FooterText()

        XCTAssertNotEqual(toggleOffText, toggleOnUnavailableText)
        XCTAssertTrue(toggleOnUnavailableText.contains("登入 iCloud"))
    }

    func test_section0FooterText_noExtraWarning_whenToggleOnAndICloudAvailable() {
        UserPreferences.shared.syncPreference = .iCloud
        let vc = SettingViewController()
        vc.iCloudAvailabilityChecking = FakeICloudAvailabilityChecker(available: true)

        let text = vc.section0FooterText()

        XCTAssertFalse(text.contains("資料將無法復原"))
    }

    // MARK: - fee settings

    private func makeDefaults() -> UserDefaults {
        let name = "SettingViewControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func makeSettings(defaults: UserDefaults) throws -> SettingViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: AddListViewController.self))
        let tab = storyboard.instantiateViewController(withIdentifier: "customTabVC") as! UITabBarController
        let nav = try XCTUnwrap(tab.viewControllers?.compactMap { $0 as? UINavigationController }
            .first { $0.viewControllers.first is SettingViewController })
        let settings = try XCTUnwrap(nav.viewControllers.first as? SettingViewController)
        settings.userDefaults = defaults
        settings.loadViewIfNeeded()
        settings.initView()
        return settings
    }

    func test_fee_section_starts_in_the_discount_mode_without_a_discount() throws {
        let settings = try makeSettings(defaults: makeDefaults())

        XCTAssertEqual(settings.feeModeControl.selectedSegmentIndex, 0)
        XCTAssertEqual(settings.feeDiscountTextfield.text, "無折扣")
        XCTAssertEqual(settings.userDefinedFeeLabel.text, "0 元")
    }

    func test_fee_section_shows_what_is_saved() throws {
        let defaults = makeDefaults()
        FeeSettings.saveMode(fixedAmount: true, userDefaults: defaults)
        FeeSettings.saveDiscount(Decimal(string: "2.8")!, userDefaults: defaults)
        FeeSettings.saveFixedAmount(30, userDefaults: defaults)

        let settings = try makeSettings(defaults: defaults)

        XCTAssertEqual(settings.feeModeControl.selectedSegmentIndex, 1)
        XCTAssertEqual(settings.feeDiscountTextfield.text, "2.8 折")
        XCTAssertEqual(settings.userDefinedFeeLabel.text, "30 元")
    }

    func test_choosing_the_fixed_amount_mode_saves_it() throws {
        let defaults = makeDefaults()
        let settings = try makeSettings(defaults: defaults)

        settings.feeModeControl.selectedSegmentIndex = 1
        settings.feeModeControl.sendActions(for: .valueChanged)

        XCTAssertTrue(FeeSettings.usesFixedAmount(userDefaults: defaults))
        XCTAssertEqual(FeeSettings.current(userDefaults: defaults).mode, .fixedAmount(0))
    }

    func test_the_fee_section_header_holds_the_mode_control() throws {
        let settings = try makeSettings(defaults: makeDefaults())

        let header = try XCTUnwrap(settings.tableView(settings.tableView, viewForHeaderInSection: 1))

        XCTAssertTrue(settings.feeModeControl.isDescendant(of: header))
        XCTAssertNil(settings.tableView(settings.tableView, viewForHeaderInSection: 0))
    }

    func test_a_typed_discount_is_saved_and_shown_with_its_unit() throws {
        let defaults = makeDefaults()
        let settings = try makeSettings(defaults: defaults)

        settings.feeDiscountTextfield.text = "2.8"
        settings.textFieldDidEndEditing(settings.feeDiscountTextfield)

        XCTAssertEqual(FeeSettings.currentDiscount(userDefaults: defaults), Decimal(string: "2.8")!)
        XCTAssertEqual(settings.feeDiscountTextfield.text, "2.8 折")
    }

    func test_a_discount_that_is_not_valid_is_not_saved_and_the_old_one_is_shown_again() throws {
        let defaults = makeDefaults()
        FeeSettings.saveDiscount(Decimal(6), userDefaults: defaults)
        let settings = try makeSettings(defaults: defaults)

        for typed in ["11", "0", "2.855", "abc", ""] {
            settings.feeDiscountTextfield.text = typed
            settings.textFieldDidEndEditing(settings.feeDiscountTextfield)

            XCTAssertEqual(FeeSettings.currentDiscount(userDefaults: defaults), 6, "\(typed)")
            XCTAssertEqual(settings.feeDiscountTextfield.text, "6 折", "\(typed)")
        }
    }

    func test_the_fixed_fee_screen_saves_a_number_rounded_down_and_refuses_text() throws {
        let defaults = makeDefaults()
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: AddListViewController.self))
        let editor = storyboard.instantiateViewController(withIdentifier: "editFeeVC") as! EditFeeViewController
        editor.userDefaults = defaults
        editor.loadViewIfNeeded()

        editor.feeTextField.text = "abc"
        editor.onTapSave(UIBarButtonItem())
        XCTAssertEqual(FeeSettings.currentFixedAmount(userDefaults: defaults), 0, "refused, nothing saved")

        editor.feeTextField.text = "20.5"
        editor.onTapSave(UIBarButtonItem())
        XCTAssertEqual(FeeSettings.currentFixedAmount(userDefaults: defaults), 20)
    }
}
