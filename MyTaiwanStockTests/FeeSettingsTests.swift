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

    @Test func aDiscountOutsideTheRangeFallsBackToTheEarlierChoiceOrNoDiscount() {
        let defaults = makeDefaults()
        defaults.set(11.0, forKey: UserDefaults.feeDiscountKey)

        #expect(FeeSettings.current(userDefaults: defaults).mode == .discount(10))
    }
}
