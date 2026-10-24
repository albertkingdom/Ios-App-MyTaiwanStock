//
//  FeeSettingsTests.swift
//  MyTaiwanStockTests
//

import Foundation
import Testing

@testable import MyTaiwanStock

struct FeeSettingsTests {
    /// A defaults store of its own, so that nothing touches the simulator's settings.
    private func makeDefaults() -> UserDefaults {
        let name = "FeeSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func withNothingSavedThereIsNoDiscount() {
        let settings = FeeSettings.current(userDefaults: makeDefaults())

        #expect(settings.mode == .discount(10))
    }

    @Test func theEarlierDiscountChoiceIsReadAsPositionPlusOneWithoutBeingWritten() {
        let defaults = makeDefaults()
        defaults.set(5, forKey: UserDefaults.userDefinedFeeDiscountKey)

        let settings = FeeSettings.current(userDefaults: defaults)

        #expect(settings.mode == .discount(6))
        #expect(defaults.object(forKey: UserDefaults.feeDiscountKey) == nil)
        #expect(defaults.object(forKey: UserDefaults.feeModeKey) == nil)
    }

    @Test func aSavedDiscountWinsOverTheEarlierChoice() {
        let defaults = makeDefaults()
        defaults.set(5, forKey: UserDefaults.userDefinedFeeDiscountKey)
        defaults.set(2.8, forKey: UserDefaults.feeDiscountKey)

        #expect(FeeSettings.current(userDefaults: defaults).mode == .discount(Decimal(string: "2.8")!))
    }

    @Test func aFixedAmountSavedEarlierDoesNotSwitchTheModeByItself() {
        let defaults = makeDefaults()
        defaults.set(20.0, forKey: UserDefaults.userDefinedFeeInDollarsKey)

        #expect(FeeSettings.current(userDefaults: defaults).mode == .discount(10))
    }

    @Test func theFixedAmountModeUsesTheSavedAmountRoundedDown() {
        let defaults = makeDefaults()
        defaults.set(20.9, forKey: UserDefaults.userDefinedFeeInDollarsKey)
        defaults.set("fixedAmount", forKey: UserDefaults.feeModeKey)

        #expect(FeeSettings.current(userDefaults: defaults).mode == .fixedAmount(20))
    }

    /// The earlier settings screen saved whatever number was typed, so the stored value may not be a usable amount.
    @Test(arguments: [(1e30, 2_147_483_647), (-5.0, 0), (Double.infinity, 0), (Double.nan, 0)])
    func aStoredAmountThatDoesNotFitIsClampedInsteadOfCrashing(_ input: (stored: Double, amount: Int)) {
        let defaults = makeDefaults()
        defaults.set(input.stored, forKey: UserDefaults.userDefinedFeeInDollarsKey)
        defaults.set("fixedAmount", forKey: UserDefaults.feeModeKey)

        #expect(FeeSettings.current(userDefaults: defaults).mode == .fixedAmount(input.amount))
    }

    @Test func aDiscountOutsideTheRangeFallsBackToTheEarlierChoiceOrNoDiscount() {
        let defaults = makeDefaults()
        defaults.set(11.0, forKey: UserDefaults.feeDiscountKey)

        #expect(FeeSettings.current(userDefaults: defaults).mode == .discount(10))
    }

    // MARK: typed discount

    @Test(arguments: [("2.8", "2.8"), ("10", "10"), ("0.1", "0.1"), ("6", "6"), (" 0.65 ", "0.65"), ("9.99", "9.99")])
    func aDiscountFromPointOneToTenWithTwoDecimalsIsAccepted(_ input: (text: String, value: String)) throws {
        #expect(try FeeSettings.parseDiscount(input.text) == Decimal(string: input.value)!)
    }

    @Test(arguments: ["0", "11", "10.01", "0.05", "2.855", "-1", "abc", "", "1e1", "2.8折", "1.2.3", "0x6"])
    func aDiscountOutOfRangeOrNotAPlainNumberIsRefused(_ text: String) {
        #expect(throws: FeeSettingsError.self) { try FeeSettings.parseDiscount(text) }
        #expect(throws: FeeSettingsError.self) { try FeeSettings.parseDiscount(nil) }
    }

    // MARK: saving

    @Test func theSavedModeDiscountAndAmountAreReadBack() {
        let defaults = makeDefaults()

        FeeSettings.saveMode(fixedAmount: true, userDefaults: defaults)
        FeeSettings.saveDiscount(Decimal(string: "2.8")!, userDefaults: defaults)
        FeeSettings.saveFixedAmount(30, userDefaults: defaults)

        #expect(FeeSettings.usesFixedAmount(userDefaults: defaults))
        #expect(FeeSettings.currentDiscount(userDefaults: defaults) == Decimal(string: "2.8")!)
        #expect(FeeSettings.currentFixedAmount(userDefaults: defaults) == 30)
        #expect(FeeSettings.current(userDefaults: defaults).mode == .fixedAmount(30))

        FeeSettings.saveMode(fixedAmount: false, userDefaults: defaults)
        #expect(FeeSettings.current(userDefaults: defaults).mode == .discount(Decimal(string: "2.8")!))
    }

    @Test func aFixedAmountIsNeverSavedNegative() {
        let defaults = makeDefaults()

        FeeSettings.saveFixedAmount(-5, userDefaults: defaults)

        #expect(FeeSettings.currentFixedAmount(userDefaults: defaults) == 0)
    }
}
