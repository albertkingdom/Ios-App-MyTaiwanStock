//
//  FeeCalculatorTests.swift
//  MyTaiwanStockTests
//

import Foundation
import Testing

@testable import MyTaiwanStock

struct FeeCalculatorTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let side: TradeSide
        let shares: Int
        let price: String
        let discount: String
        let category: TaxCategory
        let fee: Int
        let tax: Int

        var testDescription: String { "\(side) \(shares) @ \(price), discount \(discount), \(category)" }
    }

    /// The example table of the specification.
    static let cases: [Case] = [
        Case(side: .buy, shares: 1000, price: "100", discount: "10", category: .stock, fee: 142, tax: 0),
        Case(side: .sell, shares: 1000, price: "105", discount: "6", category: .stock, fee: 89, tax: 315),
        Case(side: .buy, shares: 5, price: "112.55", discount: "6", category: .stock, fee: 1, tax: 0),
        Case(side: .sell, shares: 10, price: "757", discount: "6", category: .stock, fee: 6, tax: 22),
        Case(side: .buy, shares: 1, price: "2470", discount: "6", category: .stock, fee: 2, tax: 0),
        Case(side: .buy, shares: 1000, price: "20", discount: "6", category: .stock, fee: 20, tax: 0),
        Case(side: .sell, shares: 2000, price: "22", discount: "6", category: .etf, fee: 37, tax: 44),
        Case(side: .sell, shares: 1000, price: "100", discount: "10", category: .exempt, fee: 142, tax: 0),
        Case(side: .buy, shares: 999, price: "1", discount: "10", category: .stock, fee: 1, tax: 0),
        Case(side: .buy, shares: 1500, price: "1", discount: "10", category: .stock, fee: 20, tax: 0),
    ]

    @Test(arguments: cases)
    func matchesTheSpecificationTable(_ testCase: Case) throws {
        let settings = FeeSettings(mode: .discount(try #require(Decimal(string: testCase.discount))))

        let result = FeeCalculator.calculate(
            price: try #require(Decimal(string: testCase.price)), shares: testCase.shares, side: testCase.side,
            settings: settings, taxCategory: testCase.category)

        #expect(result == FeeAndTax(fee: testCase.fee, tax: testCase.tax))
    }

    @Test func aDecimalDiscountDoesNotLoseADollar() throws {
        // 1,000,000 x 0.001425 x 0.28 is exactly 399; a binary 2.8 would give 398.
        let discount = try #require(Decimal(string: String(2.8 as Double)))

        let result = FeeCalculator.calculate(
            price: 1000, shares: 1000, side: .sell, settings: FeeSettings(mode: .discount(discount)), taxCategory: .stock)

        #expect(result?.fee == 399)
    }

    @Test func aFixedAmountReplacesTheFormulaAndTheMinimum() {
        let settings = FeeSettings(mode: .fixedAmount(30))

        #expect(FeeCalculator.calculate(price: 100, shares: 1000, side: .buy, settings: settings, taxCategory: .stock)?.fee == 30)
        #expect(FeeCalculator.calculate(price: 1, shares: 1, side: .buy, settings: settings, taxCategory: .stock)?.fee == 30)
    }

    @Test func aFixedAmountStillLeavesTheTaxOfASell() {
        let result = FeeCalculator.calculate(
            price: 105, shares: 1000, side: .sell, settings: FeeSettings(mode: .fixedAmount(30)), taxCategory: .stock)

        #expect(result == FeeAndTax(fee: 30, tax: 315))
    }

    @Test func sameDayTradeTaxIsHalfAPercentLessThanStock() {
        let result = FeeCalculator.calculate(
            price: 100, shares: 1000, side: .sell, settings: FeeSettings(mode: .discount(10)), taxCategory: .dayTrade)

        #expect(result?.tax == 150)
    }

    @Test func aBuyNeverPaysTax() {
        let result = FeeCalculator.calculate(
            price: 100, shares: 1000, side: .buy, settings: FeeSettings(mode: .discount(10)), taxCategory: .stock)

        #expect(result?.tax == 0)
    }

    @Test(arguments: [(Decimal(0), 10), (Decimal(-1), 10), (Decimal(100), 0), (Decimal(100), -5)])
    func noResultWithoutAPositivePriceAndAShare(_ input: (price: Decimal, shares: Int)) {
        let result = FeeCalculator.calculate(
            price: input.price, shares: input.shares, side: .buy, settings: FeeSettings(mode: .discount(10)), taxCategory: .stock)

        #expect(result == nil)
    }
}
