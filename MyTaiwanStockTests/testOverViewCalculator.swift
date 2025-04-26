//
//  testOverViewCalculator.swift
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
