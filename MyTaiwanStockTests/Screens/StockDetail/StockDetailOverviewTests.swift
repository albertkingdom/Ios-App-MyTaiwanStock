//
//  StockDetailOverviewTests.swift
//  MyTaiwanStockTests
//

import UIKit
import Testing

@testable import MyTaiwanStock

/// The second line in the language the test runs in.
private func feeTax(_ fee: String, _ tax: String) -> String {
    "detailVC_fee_tax_format".localized(with: [fee, tax])
}

@MainActor
struct HistoryCellModelTests {
    @Test func aBuyShowsItsProfitIncludingTheFee() {
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0)

        #expect(cell.revenueString == "4.85 %")
        #expect((cell.revenueValue ?? 0) > 0)
    }

    @Test func aLossKeepsItsSign() {
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0, current: "95")

        #expect(cell.revenueString == "-5.13 %")
        #expect((cell.revenueValue ?? 0) < 0)
    }

    @Test func aProfitThatRoundsToZeroIsShownAsZero() {
        // 100.004 against a cost of 100 is 0.004 percent, which the label shows as 0.00.
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 0, tax: 0, current: "100.004")

        #expect(cell.revenueString == "0.00 %")
        #expect(cell.revenueValue == 0)
    }

    @Test func aSellShowsNoProfit() {
        let cell = HistoryFixtures.cell(side: 1, shares: 1000, price: 105, fee: 150, tax: 315)

        #expect(cell.revenueString == "N/A")
        #expect(cell.revenueValue == nil)
    }

    @Test func withoutACurrentPriceThereIsNoProfitNumber() {
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, current: "-")

        #expect(cell.revenueValue == nil)
    }

    @Test func theSecondLineNamesTheFeeAndTheTax() {
        let cell = HistoryFixtures.cell(side: 1, shares: 1000, price: 105, fee: 142, tax: 315)

        #expect(cell.feeTaxString == feeTax("142", "315"))
    }

    @Test func aBuyStoresATaxOfZeroAndShowsIt() {
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0)

        #expect(cell.feeTaxString == feeTax("142", "0"))
    }

    @Test func recordsFromBeforeFeesWereStoredShowDashes() {
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100)

        #expect(cell.feeTaxString == feeTax("-", "-"))
    }

    @Test func theLineCarriesTheStoredFee() {
        let cell = HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142)

        #expect(cell.tradeLine.fee == 142)
        #expect(HistoryFixtures.cell(side: 0, shares: 1000, price: 100).tradeLine.fee == nil)
    }
}

@MainActor
struct StockDetailOverviewTests {
    private func makeViewModel(current: String = "105") -> StockDetailViewModel {
        StockDetailViewModel(stockNo: "0050", currentStockPrice: current, repository: MockNetworkService())
    }

    private func buy(_ shares: Int16, _ price: Float, fee: Int32? = nil) -> MyTaiwanStock.InvestHistory {
        HistoryFixtures.history(side: 0, shares: shares, price: price, fee: fee)
    }

    private func sell(_ shares: Int16, _ price: Float, fee: Int32? = nil) -> MyTaiwanStock.InvestHistory {
        HistoryFixtures.history(side: 1, shares: shares, price: price, fee: fee)
    }

    @Test func theAverageBuyPriceIncludesTheFees() {
        let viewModel = makeViewModel()

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142), buy(1000, 110, fee: 156)]

        #expect(viewModel.avgBuyPriceCombine.value == "105.15")
    }

    @Test func theAverageBuyPriceRoundsHalfUp() {
        let viewModel = makeViewModel()

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 145)]

        #expect(viewModel.avgBuyPriceCombine.value == "100.15")
    }

    @Test func anUnknownFeeCountsAsZero() {
        let viewModel = makeViewModel()

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142), buy(1000, 110)]

        #expect(viewModel.avgBuyPriceCombine.value == "105.07")
    }

    @Test func theNoteAppearsOnlyForABuyWithoutAFee() {
        let viewModel = makeViewModel()

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142), buy(1000, 110)]
        #expect(viewModel.missingFeeNoteCombine.value)

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142), sell(1000, 105)]
        #expect(!viewModel.missingFeeNoteCombine.value)
    }

    @Test func deletingTheLastBuyTurnsTheAverageIntoADash() {
        let viewModel = makeViewModel()
        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142), sell(400, 105)]
        #expect(viewModel.avgBuyPriceCombine.value == "100.14")

        viewModel.coreDataObjectsCombine = [sell(400, 105)]

        #expect(viewModel.avgBuyPriceCombine.value == "-")
    }

    @Test func onlySellsGiveNegativeHoldingsAndNoMarketValue() {
        let viewModel = makeViewModel()

        viewModel.coreDataObjectsCombine = [sell(400, 105)]

        #expect(viewModel.totalAmountCombine.value == -400)
        #expect(viewModel.totalAssetCombine.value == "-")
        #expect(viewModel.avgBuyPriceCombine.value == "-")
        #expect(viewModel.avgSellPriceCombine.value == "105.00")
    }

    @Test func theMarketValueTurnsIntoADashWhenTheHoldingsReachZero() {
        let viewModel = makeViewModel()
        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142)]
        #expect(viewModel.totalAssetCombine.value == "105000.0")

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142), sell(1000, 105, fee: 150)]

        #expect(viewModel.totalAssetCombine.value == "-")
    }

    @Test func withoutACurrentPriceTheMarketValueIsADash() {
        let viewModel = makeViewModel(current: "-")

        viewModel.coreDataObjectsCombine = [buy(1000, 100, fee: 142)]

        #expect(viewModel.totalAssetCombine.value == "-")
    }
}

@MainActor
struct NewHistoryTableViewCellTests {
    private func makeCell(_ model: HistoryCellModel) throws -> NewHistoryTableViewCell {
        let nib = UINib(nibName: "NewHistoryTableViewCell", bundle: Bundle(for: NewHistoryTableViewCell.self))
        let cell = try #require(nib.instantiate(withOwner: nil).first as? NewHistoryTableViewCell)
        cell.configure(with: model)
        return cell
    }

    @Test func aProfitIsShownInTheColorOfAGain() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0))

        #expect(cell.revenueLabel.text == "4.85 %")
        #expect(cell.revenueLabel.textColor == .red)
    }

    @Test func aLossIsShownInTheColorOfALoss() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0, current: "95"))

        #expect(cell.revenueLabel.textColor == .green)
    }

    @Test func aProfitThatRoundsToZeroKeepsTheNormalColor() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 0, tax: 0, current: "100.004"))

        #expect(cell.revenueLabel.text == "0.00 %")
        #expect(cell.revenueLabel.textColor == .label)
    }

    @Test func aSellKeepsTheNormalColor() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 1, shares: 1000, price: 105, fee: 150, tax: 315))

        #expect(cell.revenueLabel.text == "N/A")
        #expect(cell.revenueLabel.textColor == .label)
    }

    @Test func theSecondLineShowsTheFeeAndTheTax() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 1, shares: 1000, price: 105, fee: 142, tax: 315))

        #expect(cell.feeTaxLabel.text == feeTax("142", "315"))
    }

    @Test func oldRecordsShowDashesOnTheSecondLine() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 0, shares: 1000, price: 100))

        #expect(cell.feeTaxLabel.text == feeTax("-", "-"))
    }

    @Test func labelsFollowTheDynamicTypeSize() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0))

        for label in [cell.statusLabel, cell.dateLabel, cell.priceLabel, cell.amountLabel, cell.revenueLabel, cell.feeTaxLabel] {
            #expect(label?.adjustsFontForContentSizeCategory == true)
        }
    }

    @Test func accessibilitySizesStackTheValuesInsteadOfSqueezingFiveColumns() throws {
        let cell = try makeCell(HistoryFixtures.cell(side: 0, shares: 1000, price: 100, fee: 142, tax: 0))
        #expect(cell.stackView.axis == .horizontal)

        cell.updateColumnLayout(for: .accessibilityExtraExtraExtraLarge)
        #expect(cell.stackView.axis == .vertical)
        #expect(cell.priceLabel.textAlignment == .left)

        cell.updateColumnLayout(for: .large)
        #expect(cell.stackView.axis == .horizontal)
        #expect(cell.priceLabel.textAlignment == .center)
    }
}
