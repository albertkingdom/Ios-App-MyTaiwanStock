//
//  TestStockViewModel.swift
//  MyTaiwanStockTests
//
//  Created by yklin on 2024/11/24.
//

import Combine
import CoreData
import Foundation
import Testing

@testable import MyTaiwanStock

struct TestStockListViewModel {

    @Test
    @MainActor
    func test_transform_whenViewDidLoad_shouldUpdateMenuTitle()
        async throws
    {
        let mockRepository = MockNetworkService()
        let mockCoordinator = MockStockListCoordinator()
        let sut = StockListViewModel(
            repository: mockRepository, coordinator: mockCoordinator)
        var subscriptions = Set<AnyCancellable>()

        // Setup input
        let input = StockListViewModel.Input(
            didRefresh: PassthroughSubject<Void, Never>(),
            viewDidLoad: PassthroughSubject<Void, Never>()
        )
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Given
        let mockList = createMockList(name: "TestList")
        mockRepository.mockStockList = [mockList]
        let output = sut.transform(input: input)
        var menuTitles: [String] = []

        output.menuTitle
            .sink { title in
                menuTitles.append(title)
            }
            .store(in: &subscriptions)

        // When
        input.viewDidLoad.send()

        // Then
        assert(menuTitles == ["","TestList"]) // ""是初始值
    }

}

extension TestStockListViewModel {
    private func createMockList(name: String, stockNos: [String] = [])
        -> MyTaiwanStock.List
    {
        let coreDataStack = CoreDataTestStack()
        let context = coreDataStack.context

        guard
            let entityDescription = NSEntityDescription.entity(
                forEntityName: "List", in: context)
        else {
            fatalError("Failed to create List entity description")
        }

        let list = MyTaiwanStock.List(
            entity: entityDescription, insertInto: context)
        list.name = name

        stockNos.forEach { stockNo in
            guard
                let stockEntityDescription = NSEntityDescription.entity(
                    forEntityName: "StockNo", in: context)
            else {
                fatalError("Failed to create StockNo entity description")
            }
            let stockNoObject = MyTaiwanStock.StockNo(
                entity: stockEntityDescription, insertInto: context)
            stockNoObject.stockNo = stockNo
            stockNoObject.ofList = list
        }

        try? context.save()
        return list
    }
}

class CoreDataTestStack {
    private let modelName: String = "MyTaiwanStock"

    private lazy var managedObjectModel: NSManagedObjectModel = {
        // 嘗試從測試 bundle 中加載模型
        let bundle = Bundle(for: type(of: self))
        guard
            let modelURL = bundle.url(
                forResource: modelName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load Core Data model")
        }
        return model
    }()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(
            name: modelName, managedObjectModel: managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }

        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func cleanUp() {
        try? context.save()
    }
}

class MockNetworkService: NetworkService {

    // MARK: - Test Properties
    var mockStockList: [MyTaiwanStock.List] = []
    var mockOneDayStockInfo = OneDayStockInfo(msgArray: [])
    var fetchOneDayStockInfoCalled = false
    var lastFetchedStockList: [String] = []

    // MARK: - Core Methods Used in ViewModel
    func stockList() -> [MyTaiwanStock.List] {
        return mockStockList
    }

    func fetchOneDayStockInfoCombine(stockList: [String]) -> AnyPublisher<
        OneDayStockInfo, Error
    > {
        fetchOneDayStockInfoCalled = true
        lastFetchedStockList = stockList
        return Just(mockOneDayStockInfo)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    // MARK: - Helper Methods
    func simulateError() -> AnyPublisher<OneDayStockInfo, Error> {
        return Fail(error: NSError(domain: "Test", code: -1))
            .eraseToAnyPublisher()
    }

    // MARK: - Protocol Stubs
    func saveStockNumber(
        with stockNumber: String, currentFollowingList: MyTaiwanStock.List
    ) {
    }

    func deleteStockNumber(
        stockNoObject: MyTaiwanStock.StockNo, listName: String,
        stockNumber: String
    ) {}

    func updateStockNoInDBwithPrice(
        stockNos: [String], cellViewModels: [StockCellViewModel]
    ) {}

    func getAllListAndStocksFromOnlineDBAndSaveToLocal(
        completion: (() -> Void)?
    ) {
        completion?()
    }

    func getAllHistoryFromOnlineDBAndSaveToLocal() {}

    // MARK: - Unused Protocol Requirements
    func fetchOneDayStockInfo(
        stockList: [String],
        completionHandler: @escaping (Result<OneDayStockInfo, Error>) -> Void
    ) {}
    func fetchCandleData(
        stockNo: String, dateStr: String,
        completion: @escaping (Result<[[String]], Error>) -> Void
    ) {}
    func fetchTwoMonthCandleData(stockNo: String) async -> [[String]] {
        return []
    }
    func historyList(with stockNo: String) -> [MyTaiwanStock.InvestHistory] {
        return []
    }
    func fetchStockPriceFromDB(with stockNos: [String]) -> [MyTaiwanStock
        .StockNo]
    {
        return []
    }
    func fetchStockDividend() -> [MyTaiwanStock.StockDividend] { return [] }
    func fetchStockDividend(with stockNo: String) -> [MyTaiwanStock
        .StockDividend]
    {
        return []
    }
    func fetchCashDividend() -> [MyTaiwanStock.CashDividend] { return [] }
    func fetchCashDividend(with stockNo: String) -> [MyTaiwanStock.CashDividend]
    { return [] }
    func saveList(with listName: String) -> MyTaiwanStock.List { fatalError() }
    func saveNewRecord(
        stockNo: String, price: Float, amount: Int, reason: String,
        buyOrSellStatus: Int, date: Date
    ) {}
    func saveStockDividend(stockNo: String, amount: Int, date: Date) {}
    func saveCashDividend(stockNo: String, amount: Int, date: Date) {}
    func deleteHistory(historyObject: MyTaiwanStock.InvestHistory) {}
    func deleteList(list: MyTaiwanStock.List) {}
    func sendDeviceIdToServer(deviceId: String, token: String) {}
}

class MockStockListCoordinator: StockListCoordinatorProtocol {
    func showStockDetail(
        stockNo: String, currentStockPrice: String, stockName: String,
        stockPriceDiff: String, timeString: String
    ) {}
    func showAddList() {}
    func showAddStock(
        followingStockNoList: Set<String>, listName: String,
        addNewStockToDB: @escaping (String) -> Void
    ) {}
}
