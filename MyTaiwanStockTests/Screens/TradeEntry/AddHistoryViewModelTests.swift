//
//  AddHistoryViewModelTests.swift
//  MyTaiwanStockTests
//

import Foundation
import Testing

@testable import MyTaiwanStock

private final class FakeRecordSaver: RecordSaving {
    struct Saved: Equatable {
        let stockNo: String
        let price: Float
        let amount: Int
        let reason: String
        let buyOrSellStatus: Int
        let date: Date
        let fee: Int?
        let tax: Int?
    }

    private(set) var saved: [Saved] = []

    func saveNewRecord(
        stockNo: String, price: Float, amount: Int, reason: String, buyOrSellStatus: Int, date: Date,
        fee: Int?, tax: Int?
    ) {
        saved.append(
            Saved(
                stockNo: stockNo, price: price, amount: amount, reason: reason,
                buyOrSellStatus: buyOrSellStatus, date: date, fee: fee, tax: tax))
    }
}

struct AddHistoryViewModelTests {
    private let noDiscount = FeeSettings(mode: .discount(10))
    private let saver = FakeRecordSaver()

    private func makeViewModel(settings: FeeSettings? = nil) -> AddHistoryViewModel {
        let settings = settings ?? noDiscount
        return AddHistoryViewModel(feeSettings: { settings }, repository: saver)
    }

    // MARK: computing

    @Test func theFeeFollowsTheFinalTextOfTheSharesFieldWhileItIsTyped() {
        let viewModel = makeViewModel()
        var fees: [String] = []

        for typed in ["1", "10", "100", "1000"] {
            viewModel.didChange(priceText: "100", amountText: typed)
            fees.append(viewModel.feeText)
        }

        // 100 x 1 is 0.14 dollars, which the odd-lot minimum raises to 1; 1000 shares is 142.5, rounded down.
        #expect(fees == ["1", "1", "14", "142"])
    }

    @Test func theFeeFollowsTheFinalTextOfThePriceFieldWhileItIsTyped() {
        let viewModel = makeViewModel()
        var fees: [String] = []

        for typed in ["1", "10", "105", "105.", "105.5"] {
            viewModel.didChange(priceText: typed, amountText: "1000")
            fees.append(viewModel.feeText)
        }

        // 1000 shares are charged the whole-lot minimum of 20 until the formula passes it.
        #expect(fees == ["20", "20", "149", "149", "150"])
    }

    @Test func theOddLotMinimumFeeFromTheSettingsIsShown() {
        let viewModel = makeViewModel(settings: FeeSettings(mode: .discount(6), oddLotMinimumFee: 5))

        viewModel.didChange(priceText: "112.55", amountText: "5")

        #expect(viewModel.feeText == "5")
    }

    @Test func aFixedAmountReplacesTheFormula() {
        let viewModel = makeViewModel(settings: FeeSettings(mode: .fixedAmount(30)))

        viewModel.didChange(priceText: "100", amountText: "1000")

        #expect(viewModel.feeText == "30")
    }

    @Test func theDiscountFromTheSettingsIsUsed() {
        let viewModel = makeViewModel(settings: FeeSettings(mode: .discount(Decimal(string: "2.8")!)))

        viewModel.didChange(priceText: "100", amountText: "1000")

        // 100000 x 0.001425 x 0.28 = 39.9
        #expect(viewModel.feeText == "39")
    }

    @Test(arguments: [
        (nil as String?, "1000" as String?), ("", "1000"), ("100", nil), ("100", ""),
        ("abc", "1000"), ("100", "x"), ("0", "1000"), ("100", "0"), ("1e5", "1000"), ("100", "-5"),
    ])
    func thereIsNoComputedValueWithoutAUsablePriceAndShares(price: String?, amount: String?) {
        let viewModel = makeViewModel()

        viewModel.didChange(priceText: price, amountText: amount)

        #expect(viewModel.feeText == "")
        #expect(viewModel.taxText == "")
    }

    @Test func aBuyHasATaxOfZero() {
        let viewModel = makeViewModel()

        viewModel.didChange(priceText: "100", amountText: "1000")

        #expect(viewModel.side == .buy)
        #expect(viewModel.taxText == "0")
    }

    @Test(arguments: [
        (TaxCategory.stock, "300"), (TaxCategory.dayTrade, "150"), (TaxCategory.etf, "100"),
        (TaxCategory.exempt, "0"),
    ])
    func aSellComputesTheTaxFromTheChosenCategory(category: TaxCategory, tax: String) {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didSelect(side: .sell)

        viewModel.didSelect(taxCategory: category)

        #expect(viewModel.taxText == tax)
    }

    @Test func aSellStartsWithGeneralStock() {
        let viewModel = makeViewModel()

        #expect(viewModel.taxCategory == .stock)
    }

    @Test func switchingFromBuyToSellComputesTheTax() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "105", amountText: "1000")
        #expect(viewModel.taxText == "0")

        viewModel.didSelect(side: .sell)

        #expect(viewModel.taxText == "315")
    }

    @Test func switchingBackToBuyShowsNoTax() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "105", amountText: "1000")
        viewModel.didSelect(side: .sell)

        viewModel.didSelect(side: .buy)

        #expect(viewModel.taxText == "0")
    }

    @Test func aFeeBeyondWhatCanBeStoredIsNotComputed() {
        let viewModel = makeViewModel()

        viewModel.didChange(priceText: "99999999999999999999", amountText: "30000")

        #expect(viewModel.feeText == "")
    }

    // MARK: manual values

    @Test func aTypedFeeIsKeptWhenTheSharesChange() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")

        viewModel.didEditFee("50")
        viewModel.didChange(priceText: "100", amountText: "2000")

        #expect(viewModel.feeText == "50")
    }

    @Test func aTypedFeeIsKeptWhenThePriceOrTheSideChange() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee("50")

        viewModel.didChange(priceText: "200", amountText: "1000")
        viewModel.didSelect(side: .sell)

        #expect(viewModel.feeText == "50")
    }

    @Test func aTypedTaxIsKeptWhenThePriceOrTheCategoryChange() {
        let viewModel = makeViewModel()
        viewModel.didSelect(side: .sell)
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditTax("123")

        viewModel.didChange(priceText: "200", amountText: "1000")
        viewModel.didSelect(taxCategory: .etf)

        #expect(viewModel.taxText == "123")
    }

    @Test func theOtherFieldKeepsFollowingWhenOnlyOneWasTyped() {
        let viewModel = makeViewModel()
        viewModel.didSelect(side: .sell)
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee("50")

        viewModel.didChange(priceText: "100", amountText: "2000")

        #expect(viewModel.taxText == "600")
    }

    @Test func aDeletedFeeStaysEmptyWhileItIsEdited() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        #expect(viewModel.feeText == "142")

        viewModel.didEditFee("")
        viewModel.didChange(priceText: "100", amountText: "2000")

        #expect(viewModel.feeText == "")
    }

    @Test func aNumberTypedAfterDeletingEverythingIsStored() throws {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee("")
        viewModel.didEditFee("5")
        viewModel.didEditFee("50")

        viewModel.didEndEditingFee()
        try viewModel.save(stockNo: "2330", priceText: "100", amountText: "1000")

        #expect(viewModel.feeText == "50")
        #expect(saver.saved.first?.fee == 50)
    }

    @Test func leavingAnEmptyFeeShowsTheComputedValueAgain() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee("")

        viewModel.didEndEditingFee()

        #expect(viewModel.feeText == "142")
    }

    @Test func leavingAnEmptyFeeGoesBackToComputingIt() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee("")
        viewModel.didEndEditingFee()

        viewModel.didChange(priceText: "100", amountText: "2000")

        #expect(viewModel.feeText == "285")
    }

    @Test func leavingAnEmptyTaxShowsTheComputedValueAgain() {
        let viewModel = makeViewModel()
        viewModel.didSelect(side: .sell)
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditTax("")

        viewModel.didEndEditingTax()

        #expect(viewModel.taxText == "300")
    }

    @Test func leavingAFilledFeeKeepsItManual() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee("50")

        viewModel.didEndEditingFee()
        viewModel.didChange(priceText: "100", amountText: "2000")

        #expect(viewModel.feeText == "50")
    }

    @Test func changesAreReported() {
        let viewModel = makeViewModel()
        var reports = 0
        viewModel.onChange = { reports += 1 }

        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didSelect(side: .sell)
        viewModel.didSelect(taxCategory: .etf)

        #expect(reports == 3)
    }

    // MARK: saving

    @Test func aBuyIsSavedWithTheFeeFromTheFieldAndATaxOfZero() throws {
        let viewModel = makeViewModel()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        viewModel.date = date
        viewModel.memo = "dip"
        viewModel.didChange(priceText: "105", amountText: "1000")

        try viewModel.save(stockNo: "2330", priceText: "105", amountText: "1000")

        #expect(
            saver.saved == [
                FakeRecordSaver.Saved(
                    stockNo: "2330", price: 105, amount: 1000, reason: "dip", buyOrSellStatus: 0,
                    date: date, fee: 149, tax: 0)
            ])
    }

    @Test func aBuyIgnoresATaxTypedBeforeSwitchingBack() throws {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "105", amountText: "1000")
        viewModel.didSelect(side: .sell)
        viewModel.didEditTax("999")
        viewModel.didSelect(side: .buy)

        try viewModel.save(stockNo: "2330", priceText: "105", amountText: "1000")

        #expect(saver.saved.first?.tax == 0)
        #expect(saver.saved.first?.buyOrSellStatus == 0)
    }

    @Test func aSellIsSavedWithTheTaxFromTheField() throws {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "105", amountText: "1000")
        viewModel.didSelect(side: .sell)
        viewModel.didSelect(taxCategory: .etf)

        try viewModel.save(stockNo: "0050", priceText: "105", amountText: "1000")

        #expect(saver.saved.first?.buyOrSellStatus == 1)
        #expect(saver.saved.first?.fee == 149)
        #expect(saver.saved.first?.tax == 105)
    }

    @Test func aTypedValueIsWhatIsSaved() throws {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "105", amountText: "1000")
        viewModel.didSelect(side: .sell)
        viewModel.didEditFee("77")
        viewModel.didEditTax("88")

        try viewModel.save(stockNo: "2330", priceText: "105", amountText: "1000")

        #expect(saver.saved.first?.fee == 77)
        #expect(saver.saved.first?.tax == 88)
    }

    @Test func moreThan32767SharesAreRejectedAndNothingIsSaved() {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "32768")

        #expect(throws: ValidationError.invalidAmount) {
            try viewModel.save(stockNo: "2330", priceText: "100", amountText: "32768")
        }
        #expect(saver.saved.isEmpty)
    }

    @Test func aBadPriceIsRejectedAndNothingIsSaved() {
        let viewModel = makeViewModel()

        #expect(throws: ValidationError.invalidPrice) {
            try viewModel.save(stockNo: "2330", priceText: "", amountText: "1000")
        }
        #expect(saver.saved.isEmpty)
    }

    @Test(arguments: ["-5", "1.5", "abc", "2147483648", "", "  "])
    func aBadFeeIsRejectedAndNothingIsSaved(fee: String) {
        let viewModel = makeViewModel()
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditFee(fee)

        #expect(throws: ValidationError.invalidFeeOrTax) {
            try viewModel.save(stockNo: "2330", priceText: "100", amountText: "1000")
        }
        #expect(saver.saved.isEmpty)
    }

    @Test func aBadTaxIsRejectedForASellAndNothingIsSaved() {
        let viewModel = makeViewModel()
        viewModel.didSelect(side: .sell)
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditTax("-1")

        #expect(throws: ValidationError.invalidFeeOrTax) {
            try viewModel.save(stockNo: "2330", priceText: "100", amountText: "1000")
        }
        #expect(saver.saved.isEmpty)
    }

    @Test func aBadTaxIsNotLookedAtForABuy() throws {
        let viewModel = makeViewModel()
        viewModel.didSelect(side: .sell)
        viewModel.didChange(priceText: "100", amountText: "1000")
        viewModel.didEditTax("-1")
        viewModel.didSelect(side: .buy)

        try viewModel.save(stockNo: "2330", priceText: "100", amountText: "1000")

        #expect(saver.saved.first?.tax == 0)
    }
}

extension AddHistoryViewModelTests {
    @Test(arguments: ["inf", "1e50"])
    func aNonFinitePriceCannotBeSavedWithAManualFee(price: String) {
        let viewModel = makeViewModel()
        viewModel.didEditFee("50")
        #expect(throws: ValidationError.invalidPrice) {
            try viewModel.save(stockNo: "2330", priceText: price, amountText: "1000")
        }
        #expect(saver.saved.isEmpty)
    }
}
