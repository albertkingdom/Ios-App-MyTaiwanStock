//
//  OverViewCalculatorTests.swift
//  MyTaiwanStockTests
//
//  Created by yklin on 2024/11/24.
//

import CoreData
import Testing

@testable import MyTaiwanStock

// 創建一個 Mock InvestHistory 類別
class MockInvestHistory: InvestHistory {
    private var mockAmount: Int16 = 0
    private var mockStatus: Int16 = 0
    private var mockPrice: Float = 0.0
    private var mockDate: Date = Date()

    override var amount: Int16 {
        get { return mockAmount }
        set { mockAmount = newValue }
    }

    override var status: Int16 {
        get { return mockStatus }
        set { mockStatus = newValue }
    }

    override var price: Float {
        get { return mockPrice }
        set { mockPrice = newValue }
    }

    override var date: Date? {
        get { return mockDate }
        set { mockDate = newValue ?? Date() }
    }

    // 提供一個便利的初始化方法
    static func createMock(
        amount: Int16, status: Int16, price: Float, date: Date
    ) -> MockInvestHistory {
        let mock = MockInvestHistory()
        mock.amount = amount
        mock.status = status
        mock.price = price
        mock.date = date
        return mock
    }
}

struct testOverViewCalculator {
    //    var container: NSPersistentContainer! {
    //        let container = NSPersistentContainer(name: "MyTaiwanStock1")
    //        let description = NSPersistentStoreDescription()
    //        description.type = NSInMemoryStoreType
    //        container.persistentStoreDescriptions = [description]
    //
    //        container.loadPersistentStores { description, error in
    //            assert(error == nil)
    //        }
    //        return container
    //    }
    //    private func createMockHistoryData(
    //        amount: Int16, status: Int16, price: Float, date: Date
    //    ) -> InvestHistory {
    //        let context = container.viewContext
    //        let history = InvestHistory(context: context)
    //        history.amount = amount
    //        history.status = status
    //        history.price = price
    //        history.date = date
    //        return history
    //    }

//    @Test func test_total_amount_success() async throws {
//        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
//        let mockHistoryData1 = MockInvestHistory.createMock(
//            amount: 100, status: 0, price: 50.0, date: Date())
//        let mockHistoryData2 = MockInvestHistory.createMock(
//            amount: 200, status: 1, price: 60.0, date: Date())
//        let mockHistoryData3 = MockInvestHistory.createMock(
//            amount: 300, status: 0, price: 70.0, date: Date())
//
//        let historyCellModel1 = HistoryCellModel(
//            historyData: mockHistoryData1, currentStockPrice: "55.0")
//        let historyCellModel2 = HistoryCellModel(
//            historyData: mockHistoryData2, currentStockPrice: "65.0")
//        let historyCellModel3 = HistoryCellModel(
//            historyData: mockHistoryData3, currentStockPrice: "75.0")
//
//        let historys = [
//            historyCellModel1,
//            historyCellModel2,
//            historyCellModel3,
//        ]
//
//        // When
//        let calculator = OverViewCalculator(
//            historys: historys, stockPrice: 80.0)
//
//        // Then
//        #expect(
//            calculator.amount == 600,
//
//            "Total amount should be 600 (100 + 200 + 300)")
//
//    }
    @Test func testTotalAmountWithEmptyHistory() {
        // Given
        let historys: [HistoryCellModel] = []

        // When
        let calculator = OverViewCalculator(
            historys: historys, stockPrice: 80.0)

        // Then
        #expect(
            calculator.amount == 0, "Total amount should be 0 for empty history"
        )
    }
//    計算邏輯怪怪的
//    @Test func testAverageBuyPrice() {
//        let mockHistoryData1 = MockInvestHistory.createMock(
//            amount: 100, status: 0, price: 50.0, date: Date())
//        let mockHistoryData2 = MockInvestHistory.createMock(
//            amount: 200, status: 1, price: 60.0, date: Date())
//        let mockHistoryData3 = MockInvestHistory.createMock(
//            amount: 300, status: 0, price: 70.0, date: Date())
//
//        let historyCellModel1 = HistoryCellModel(
//            historyData: mockHistoryData1, currentStockPrice: "55.0")
//        let historyCellModel2 = HistoryCellModel(
//            historyData: mockHistoryData2, currentStockPrice: "65.0")
//        let historyCellModel3 = HistoryCellModel(
//            historyData: mockHistoryData3, currentStockPrice: "75.0")
//
//        let historys = [
//            historyCellModel1,
//            historyCellModel2,
//            historyCellModel3,
//        ]
//        let calculator = OverViewCalculator(
//            historys: historys, stockPrice: 80.0)
//        let avgBuy = (100*50.0+300*70.0)/(100+200+300)
//        // Then
//        #expect(
//            calculator.averageBuyPrice() == Float(avgBuy)
//        )
//    }
    
//    @Test func testAverageSellPrice() {
//        let mockHistoryData1 = MockInvestHistory.createMock(
//            amount: 100, status: 0, price: 50.0, date: Date())
//        let mockHistoryData2 = MockInvestHistory.createMock(
//            amount: 200, status: 1, price: 60.0, date: Date())
//        let mockHistoryData3 = MockInvestHistory.createMock(
//            amount: 300, status: 0, price: 70.0, date: Date())
//
//        let historyCellModel1 = HistoryCellModel(
//            historyData: mockHistoryData1, currentStockPrice: "55.0")
//        let historyCellModel2 = HistoryCellModel(
//            historyData: mockHistoryData2, currentStockPrice: "65.0")
//        let historyCellModel3 = HistoryCellModel(
//            historyData: mockHistoryData3, currentStockPrice: "75.0")
//
//        let historys = [
//            historyCellModel1,
//            historyCellModel2,
//            historyCellModel3,
//        ]
//        let calculator = OverViewCalculator(
//            historys: historys, stockPrice: 80.0)
//        let avgSell = (200*60.0)/(200)
//        // Then
//        #expect(
//            calculator.averageSellPrice() == Float(avgSell)
//        )
//    }
}

// MARK: - holdings and average prices with sell records

/// One in-memory store for the whole file: a managed object keeps only a weak reference to its context.
@MainActor
private enum HistoryFixtures {
    static let container: NSPersistentContainer = {
        let url = Bundle(for: LocalDBService.self).url(forResource: "MyTaiwanStock", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: url)!
        let container = NSPersistentContainer(name: "MyTaiwanStock", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in precondition(error == nil) }
        return container
    }()

    /// `side` is 0 for a buy and 1 for a sell, as stored.
    static func cell(side: Int16, shares: Int16, price: Float) -> HistoryCellModel {
        let history = MyTaiwanStock.InvestHistory(context: container.viewContext)  // the test target also generates its own InvestHistory
        history.stockNo = "0050"
        history.status = side
        history.amount = shares
        history.price = price
        history.date = Date()
        return HistoryCellModel(historyData: history, currentStockPrice: "105")
    }
}

@MainActor
struct OverViewHoldingsTests {
    private func calculator(_ cells: [HistoryCellModel]) -> OverViewCalculator {
        OverViewCalculator(historys: cells, stockPrice: 105)
    }

    @Test func holdingsAreBuysMinusSells() {
        let sut = calculator([
            HistoryFixtures.cell(side: 0, shares: 1000, price: 100),
            HistoryFixtures.cell(side: 1, shares: 400, price: 105),
        ])

        #expect(sut.amount == 600)
    }

    @Test func buyingAndSellingTheSameSharesLeavesNothing() {
        let sut = calculator([
            HistoryFixtures.cell(side: 0, shares: 1000, price: 100),
            HistoryFixtures.cell(side: 1, shares: 1000, price: 105),
        ])

        #expect(sut.amount == 0)
    }

    @Test func onlySellsGiveNegativeHoldings() {
        let sut = calculator([HistoryFixtures.cell(side: 1, shares: 400, price: 105)])

        #expect(sut.amount == -400)
    }
}

struct OverViewAveragesTests {
    private func line(_ side: TradeSide, _ shares: Int, _ price: Decimal) -> TradeLine {
        TradeLine(side: side, shares: shares, price: price, fee: nil)
    }

    @Test func averageBuyPriceIgnoresSells() {
        let sut = OverViewCalculator(
            lines: [line(.buy, 1000, 100), line(.buy, 1000, 110), line(.sell, 500, 120)], stockPrice: nil)

        #expect(sut.averageBuyPrice() == 105)
        #expect(sut.amount == 1500)
    }

    @Test func averageSellPriceIsTheValueOfTheSellsOverTheirShares() {
        let sut = OverViewCalculator(
            lines: [line(.buy, 1000, 100), line(.sell, 200, 120), line(.sell, 300, 130)], stockPrice: nil)

        #expect(sut.averageSellPrice() == 126)
    }

    @Test func withoutBuysThereIsNoAverageBuyPrice() {
        let sut = OverViewCalculator(lines: [line(.sell, 400, 105)], stockPrice: nil)

        #expect(sut.averageBuyPrice() == nil)
        #expect(sut.averageSellPrice() == 105)
    }

    @Test func withoutSellsThereIsNoAverageSellPrice() {
        let sut = OverViewCalculator(lines: [line(.buy, 1000, 100)], stockPrice: nil)

        #expect(sut.averageSellPrice() == nil)
    }

    @Test func noRecordsGiveNoAveragesAndNoHoldings() {
        let sut = OverViewCalculator(lines: [], stockPrice: 105)

        #expect(sut.amount == 0)
        #expect(sut.averageBuyPrice() == nil)
        #expect(sut.averageSellPrice() == nil)
    }

    @Test func pricesAreShownWithTwoDecimalsRoundedHalfUp() {
        #expect(OverViewCalculator.format(Decimal(string: "100.145")) == "100.15")
        #expect(OverViewCalculator.format(Decimal(string: "105.149")) == "105.15")
        #expect(OverViewCalculator.format(Decimal(105)) == "105.00")
        #expect(OverViewCalculator.format(nil) == "-")
    }

    @Test func aPriceOfAFloatKeepsItsShortestText() {
        // 112.55 as a Float is 112.5500030517578125; the line has to carry 112.55.
        let text = String(Float(112.55))
        #expect(Decimal(string: text) == Decimal(string: "112.55"))
    }
}
