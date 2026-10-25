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
        settings.refreshFeeSummary()
        return settings
    }

    /// The only cell of the fee section, as the table's data source returns it for the storyboard.
    private func feeRowCell(_ settings: SettingViewController) throws -> UITableViewCell {
        XCTAssertEqual(settings.tableView(settings.tableView, numberOfRowsInSection: 1), 1)
        return try XCTUnwrap(settings.tableView.dataSource?.tableView(
            settings.tableView, cellForRowAt: SettingViewController.feeRow))
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    func test_fee_row_in_storyboard_is_titled_fee_and_holds_the_summary() throws {
        let settings = try makeSettings(defaults: makeDefaults())
        let cell = try feeRowCell(settings)

        let titles = descendants(of: cell.contentView).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(titles.contains("手續費"))
        XCTAssertTrue(settings.feeSummaryLabel.isDescendant(of: cell.contentView))
    }

    func test_fee_row_has_no_segmented_control_or_text_field() throws {
        let settings = try makeSettings(defaults: makeDefaults())
        let cell = try feeRowCell(settings)

        let inputs = descendants(of: cell.contentView).filter { $0 is UITextField || $0 is UISegmentedControl }
        XCTAssertTrue(inputs.isEmpty)
    }

    func test_fee_summary_shows_the_defaults_when_nothing_is_saved() throws {
        let settings = try makeSettings(defaults: makeDefaults())

        XCTAssertEqual(settings.feeSummaryLabel.text, "無折扣・最低 20 / 1 元")
    }

    func test_fee_summary_is_refreshed_when_the_screen_appears_again() throws {
        let defaults = makeDefaults()
        let settings = try makeSettings(defaults: defaults)

        FeeSettings.save(
            FeeSettings(discount: Decimal(string: "2.8")!, wholeLotMinimumFee: 30, oddLotMinimumFee: 5),
            userDefaults: defaults)
        settings.viewWillAppear(false)

        XCTAssertEqual(settings.feeSummaryLabel.text, "2.8 折・最低 30 / 5 元")
    }

    func test_tapping_the_fee_row_pushes_the_fee_page_with_the_same_defaults() throws {
        let defaults = makeDefaults()
        let settings = try makeSettings(defaults: defaults)
        let nav = UINavigationController(rootViewController: settings)

        settings.tableView(settings.tableView, didSelectRowAt: SettingViewController.feeRow)

        let feePage = try XCTUnwrap(nav.topViewController as? FeeSettingsViewController)
        XCTAssertTrue(feePage.userDefaults === defaults)
    }

    func test_zh_hant_translation_names_the_fee_row_and_drops_the_removed_keys() throws {
        let path = try XCTUnwrap(Bundle(for: SettingViewController.self).path(forResource: "zh-Hant", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))

        XCTAssertEqual(bundle.localizedString(forKey: "mPW-VC-YWK.text", value: nil, table: "Main"), "手續費")
        for key in ["ss2-gw-9Vk.text", "DgW-h3-Tq7.text", "JkS-Y3-3X6.text"] {
            XCTAssertEqual(bundle.localizedString(forKey: key, value: nil, table: "Main"), key)
        }
    }
}
