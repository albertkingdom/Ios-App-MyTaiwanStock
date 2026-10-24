//
//  FeeTaxFieldsTests.swift
//  MyTaiwanStockTests
//

import Testing

@testable import MyTaiwanStock

struct FeeTaxFieldsTests {
    private let estimate = FeeAndTax(fee: 6, tax: 22)

    private func refreshed(_ side: TradeSide = .sell) -> FeeTaxFields {
        var fields = FeeTaxFields()
        fields.refresh(with: estimate, side: side)
        return fields
    }

    @Test func theEstimateFillsBothFields() {
        let fields = refreshed()

        #expect(fields.feeText == "6")
        #expect(fields.taxText == "22")
        #expect(!fields.feeIsManual && !fields.taxIsManual)
    }

    @Test func withoutAnEstimateTheFieldsAreEmpty() {
        var fields = refreshed()

        fields.refresh(with: nil, side: .sell)

        #expect(fields.feeText == "")
        #expect(fields.taxText == "")
    }

    @Test func aTypedFeeSurvivesANewEstimateWhileTheTaxFollows() {
        var fields = refreshed()
        fields.editFee("3")

        fields.refresh(with: FeeAndTax(fee: 12, tax: 44), side: .sell)

        #expect(fields.feeText == "3")
        #expect(fields.feeIsManual)
        #expect(fields.taxText == "44")
    }

    @Test func aTypedTaxSurvivesANewEstimate() {
        var fields = refreshed()
        fields.editTax("30")

        fields.refresh(with: FeeAndTax(fee: 12, tax: 44), side: .sell)

        #expect(fields.taxText == "30")
        #expect(fields.feeText == "12")
    }

    @Test func aDeletedFeeStaysEmptyWhileItIsEdited() {
        var fields = refreshed()
        fields.editFee("3")
        fields.editFee("")

        fields.refresh(with: estimate, side: .sell)

        #expect(fields.feeText == "")
        #expect(fields.feeIsManual)
    }

    @Test func leavingAnEmptyFeeGoesBackToTheEstimate() {
        var fields = refreshed()
        fields.editFee("  ")

        fields.endEditingFee()
        fields.refresh(with: estimate, side: .sell)

        #expect(fields.feeText == "6")
        #expect(!fields.feeIsManual)
    }

    @Test func leavingAnEmptyTaxGoesBackToTheEstimate() {
        var fields = refreshed()
        fields.editTax("")

        fields.endEditingTax()
        fields.refresh(with: estimate, side: .sell)

        #expect(fields.taxText == "22")
        #expect(!fields.taxIsManual)
    }

    @Test func leavingAFilledFieldKeepsItManual() {
        var fields = refreshed()
        fields.editFee("3")

        fields.endEditingFee()

        #expect(fields.feeIsManual)
    }

    @Test func aBuyHasATaxOfZeroAndForgetsATypedTax() {
        var fields = refreshed()
        fields.editTax("30")

        fields.refresh(with: FeeAndTax(fee: 6, tax: 0), side: .buy)
        #expect(fields.taxText == "0")
        #expect(!fields.taxIsManual)

        fields.refresh(with: estimate, side: .sell)
        #expect(fields.taxText == "22")
    }

    @Test(arguments: ["0", "5", "2147483647"])
    func wholeNumbersInRangeAreValid(text: String) {
        var fields = FeeTaxFields()
        fields.editFee(text)
        fields.editTax(text)

        #expect(fields.fee == Int(text))
        #expect(fields.tax == Int(text))
    }

    @Test(arguments: ["-5", "5.5", "abc", "1e3", "2147483648", "", "  "])
    func anythingElseIsNotAFeeOrTax(text: String) {
        var fields = FeeTaxFields()
        fields.editFee(text)
        fields.editTax(text)

        #expect(fields.fee == nil)
        #expect(fields.tax == nil)
    }
}
