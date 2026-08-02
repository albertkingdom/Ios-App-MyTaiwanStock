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
}
