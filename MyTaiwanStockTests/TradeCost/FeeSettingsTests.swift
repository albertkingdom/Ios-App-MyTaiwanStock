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

        #expect(settings.discount == 10)
    }

    @Test func theEarlierDiscountChoiceIsReadAsPositionPlusOneWithoutBeingWritten() {
        let defaults = makeDefaults()
        defaults.set(5, forKey: UserDefaults.userDefinedFeeDiscountKey)

        let settings = FeeSettings.current(userDefaults: defaults)

        #expect(settings.discount == 6)
        #expect(defaults.object(forKey: UserDefaults.feeDiscountKey) == nil)
        #expect(defaults.object(forKey: "feeMode") == nil)
    }

    @Test func aSavedDiscountWinsOverTheEarlierChoice() {
        let defaults = makeDefaults()
        defaults.set(5, forKey: UserDefaults.userDefinedFeeDiscountKey)
        defaults.set(2.8, forKey: UserDefaults.feeDiscountKey)

        #expect(FeeSettings.current(userDefaults: defaults).discount == Decimal(string: "2.8")!)
    }

    @Test func aDiscountOutsideTheRangeFallsBackToTheEarlierChoiceOrNoDiscount() {
        let defaults = makeDefaults()
        defaults.set(11.0, forKey: UserDefaults.feeDiscountKey)

        #expect(FeeSettings.current(userDefaults: defaults).discount == 10)
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

    // MARK: minimum fees

    @Test func withNothingSavedTheMinimumFeesAreTheDefaults() {
        let settings = FeeSettings.current(userDefaults: makeDefaults())

        #expect(settings.wholeLotMinimumFee == 20)
        #expect(settings.oddLotMinimumFee == 1)
    }

    @Test func theSavedMinimumFeesAreReadBack() {
        let defaults = makeDefaults()
        defaults.set(30, forKey: UserDefaults.feeMinimumWholeLotKey)
        defaults.set(5, forKey: UserDefaults.feeMinimumOddLotKey)

        let settings = FeeSettings.current(userDefaults: defaults)

        #expect(settings.wholeLotMinimumFee == 30)
        #expect(settings.oddLotMinimumFee == 5)
    }

    @Test func zeroAndTheLargestRecordAmountAreSavedMinimumFees() {
        let defaults = makeDefaults()
        defaults.set(0, forKey: UserDefaults.feeMinimumWholeLotKey)
        defaults.set(2_147_483_647, forKey: UserDefaults.feeMinimumOddLotKey)

        let settings = FeeSettings.current(userDefaults: defaults)

        #expect(settings.wholeLotMinimumFee == 0)
        #expect(settings.oddLotMinimumFee == 2_147_483_647)
    }

    @Test func aMinimumFeeThatIsNotAWholeNumberInRangeFallsBackToTheDefault() {
        // 25.0 is a Double and true is a Bool; neither was saved as a whole number, though both bridge to an Int.
        let invalidValues: [Any] = ["20", 20.5, -1, 2_147_483_648, 25.0, true]
        for value in invalidValues {
            let defaults = makeDefaults()
            defaults.set(value, forKey: UserDefaults.feeMinimumWholeLotKey)
            defaults.set(value, forKey: UserDefaults.feeMinimumOddLotKey)

            let settings = FeeSettings.current(userDefaults: defaults)

            #expect(settings.wholeLotMinimumFee == 20, "whole-lot minimum for \(value)")
            #expect(settings.oddLotMinimumFee == 1, "odd-lot minimum for \(value)")
        }
    }

    @Test func readingTheMinimumFeesWritesNothing() {
        let defaults = makeDefaults()
        defaults.set("20", forKey: UserDefaults.feeMinimumWholeLotKey)

        _ = FeeSettings.current(userDefaults: defaults)

        #expect(defaults.object(forKey: UserDefaults.feeMinimumWholeLotKey) as? String == "20")
        #expect(defaults.object(forKey: UserDefaults.feeMinimumOddLotKey) == nil)
    }

    /// Keys left by the earlier fixed-amount setting are ignored: the formula with the default discount applies,
    /// and neither the old keys nor the new ones are written.
    @Test func oldFixedAmountKeysAreIgnoredAndNotChanged() {
        let defaults = makeDefaults()
        defaults.set("fixedAmount", forKey: "feeMode")
        defaults.set(30.0, forKey: "userDefinedFeeInDollars")

        let settings = FeeSettings.current(userDefaults: defaults)
        let result = FeeCalculator.calculate(
            price: 100, shares: 1000, side: .buy, settings: settings, taxCategory: .stock)

        #expect(settings == FeeSettings())
        #expect(result?.fee == 142)
        #expect(defaults.string(forKey: "feeMode") == "fixedAmount")
        #expect(defaults.double(forKey: "userDefinedFeeInDollars") == 30)
        #expect(defaults.object(forKey: UserDefaults.feeDiscountKey) == nil)
        #expect(defaults.object(forKey: UserDefaults.feeMinimumWholeLotKey) == nil)
        #expect(defaults.object(forKey: UserDefaults.feeMinimumOddLotKey) == nil)
    }

    // MARK: the three values together

    /// Seeds a store with saved values, runs the settings page's save path, and checks that a rejected set changed nothing.
    private func expectRejected(
        _ error: FeeSettingsError, discountText: String?, wholeLotMinimumText: String?, oddLotMinimumText: String?
    ) {
        let defaults = makeDefaults()
        defaults.set(6.0, forKey: UserDefaults.feeDiscountKey)
        defaults.set(30, forKey: UserDefaults.feeMinimumWholeLotKey)
        defaults.set(5, forKey: UserDefaults.feeMinimumOddLotKey)
        defaults.set("fixedAmount", forKey: "feeMode")

        #expect(throws: error) {
            let settings = try FeeSettings.parse(
                discountText: discountText, wholeLotMinimumText: wholeLotMinimumText,
                oddLotMinimumText: oddLotMinimumText)
            FeeSettings.save(settings, userDefaults: defaults)
        }

        #expect(defaults.double(forKey: UserDefaults.feeDiscountKey) == 6)
        #expect(defaults.object(forKey: UserDefaults.feeMinimumWholeLotKey) as? Int == 30)
        #expect(defaults.object(forKey: UserDefaults.feeMinimumOddLotKey) as? Int == 5)
        #expect(defaults.string(forKey: "feeMode") == "fixedAmount")
    }

    @Test(arguments: ["0", "11", "2.855", "abc", ""])
    func anInvalidDiscountIsRefusedAndNothingIsSaved(_ text: String) {
        expectRejected(.invalidDiscount, discountText: text, wholeLotMinimumText: "20", oddLotMinimumText: "1")
    }

    @Test(arguments: ["-1", "20.5", "abc", "", "2147483648"])
    func anInvalidWholeLotMinimumFeeIsRefusedAndNothingIsSaved(_ text: String) {
        expectRejected(.invalidWholeLotMinimumFee, discountText: "2.8", wholeLotMinimumText: text, oddLotMinimumText: "1")
    }

    @Test(arguments: ["-1", "20.5", "abc", "", "2147483648"])
    func anInvalidOddLotMinimumFeeIsRefusedAndNothingIsSaved(_ text: String) {
        expectRejected(.invalidOddLotMinimumFee, discountText: "2.8", wholeLotMinimumText: "20", oddLotMinimumText: text)
    }

    @Test func aBadDiscountIsReportedBeforeTheMinimumFees() {
        expectRejected(.invalidDiscount, discountText: "11", wholeLotMinimumText: "-1", oddLotMinimumText: "abc")
    }

    @Test func aBadWholeLotMinimumFeeIsReportedBeforeTheOddLotOne() {
        expectRejected(.invalidWholeLotMinimumFee, discountText: "2.8", wholeLotMinimumText: "-1", oddLotMinimumText: "abc")
    }

    @Test func validValuesAreSavedTogetherAndReadBack() throws {
        let defaults = makeDefaults()
        defaults.set("fixedAmount", forKey: "feeMode")

        let settings = try FeeSettings.parse(discountText: "2.8", wholeLotMinimumText: "30", oddLotMinimumText: "5")
        FeeSettings.save(settings, userDefaults: defaults)

        let read = FeeSettings.current(userDefaults: defaults)
        #expect(read.discount == Decimal(string: "2.8")!)
        #expect(read.wholeLotMinimumFee == 30)
        #expect(read.oddLotMinimumFee == 5)
        #expect(defaults.string(forKey: "feeMode") == "fixedAmount")
    }

    @Test func aParsedDiscountIsKept() throws {
        let settings = try FeeSettings.parse(discountText: "6", wholeLotMinimumText: "20", oddLotMinimumText: "1")

        #expect(settings.discount == 6)
    }

    // MARK: summary

    @Test func theSummaryShowsTheDiscountAndBothMinimumFees() {
        let settings = FeeSettings(discount: Decimal(string: "2.8")!)

        #expect(settings.summaryText == "2.8 折・最低 20 / 1 元")
    }

    @Test func theSummaryOfNoDiscountSaysSo() {
        let settings = FeeSettings(discount: 10)

        #expect(settings.summaryText == "無折扣・最低 20 / 1 元")
    }

    @Test func aMinimumFeeOfZeroIsShownAsZero() {
        let settings = FeeSettings(discount: 6, wholeLotMinimumFee: 0, oddLotMinimumFee: 5)

        #expect(settings.summaryText == "6 折・最低 0 / 5 元")
    }
}
