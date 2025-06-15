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
    let mockRepository = MockNetworkService()
    let mockCoordinator = MockStockListCoordinator()

    @Test
    func testViewDidLoadWithValidLists() async {
        var subscriptions = Set<AnyCancellable>()

        var viewModel = StockListViewModel(
            repository: mockRepository, coordinator: mockCoordinator)
        // Given
        let viewDidLoad = PassthroughSubject<Void, Never>()
        let didRefresh = PassthroughSubject<Void, Never>()
        let toggleFormat = PassthroughSubject<Void, Never>()
        let input = StockListViewModel.Input(
            didRefresh: didRefresh,
            viewDidLoad: viewDidLoad,
            togglePriceDiffFormat: toggleFormat
        )

        let mockLists = [
            createMockList(name: "List 1"),
            createMockList(name: "List 2"),
        ]
        //mockLists[0].name = "List 1"
        //mockLists[1].name = "List 2"

        mockRepository.mockStockList = mockLists

        // When
        let output = viewModel.transform(input: input)

        output.menuTitle
            .last()
            .sink { title in
                #expect(title == "List 1", "Lists loaded")
            }
            .store(in: &subscriptions)

        viewDidLoad.send()

        // Then

        assert(viewModel.listNames == ["List 1", "List 2"])
        assert(viewModel.isLoading == false)
        assert(viewModel.shouldShowAlert == false)
    }
    @Test
    func testStockCellDataFiltering() {
        var subscriptions = Set<AnyCancellable>()
        let viewModel = StockListViewModel(
            repository: mockRepository, coordinator: mockCoordinator)
        // Given

        let testStocks = [
            StockCellViewModel(stockNo: "2330"),
            StockCellViewModel(stockNo: "2317"),
            StockCellViewModel(stockNo: "2454"),
        ]

        var filteredResults: [[StockCellViewModel]] = []

        viewModel.filteredStockCellDatasCombine
            //.last()
            .sink { stockCells in
                filteredResults.append(stockCells)
                if filteredResults.count == 2 {  // 我們期望有兩次結果
                    #expect(
                        filteredResults.count == 2, "Stock cell data filtering")
                }
            }
            .store(in: &subscriptions)

        // When
        viewModel.stockCellDatasCombine.send(testStocks)
        viewModel.searchText.send("23")  // 搜尋包含 "23" 的股票代碼

        // Then

        assert(filteredResults[0].count == 3)  // 初始應該有3個股票
        assert(filteredResults[1].count == 2)  // 搜尋"23"後應該剩2個股票
    }

//        @Test
//            func testPriceDiffFormatToggle() {
//                // Given
//                let expectation = XCTestExpectation(description: "Price diff format toggle")
//                let testStock = StockCellViewModel(stockNo: "2330")
//    
//                var formatResults: [StockCellViewModel.PriceDiffFormat] = []
//    
//                viewModel.filteredStockCellDatasCombine
//                    .sink { stockCells in
//                        if let format = stockCells.first?.priceDiffFormat {
//                            formatResults.append(format)
//                        }
//                        if formatResults.count == 2 { // 我們期望有兩種格式
//                            expectation.fulfill()
//                        }
//                    }
//                    .store(in: &subscriptions)
//    
//                // When
//                viewModel.stockCellDatasCombine.send([testStock])
//                viewModel.priceDiffFormat.send(.Percentage)
//    
//                // Then
//                wait(for: [expectation], timeout: 1.0)
//                XCTAssertEqual(formatResults[0], .Digit) // 初始應為Digit格式
//                XCTAssertEqual(formatResults[1], .Percentage) // 切換後應為Percentage格式
//            }
    @Test
    @MainActor
    func test_transform_whenSearchTextChanged_shouldFilterStocks() async throws
    {
        // Given
        let mockRepository = MockNetworkService()
        let mockCoordinator = MockStockListCoordinator()
        let sut = StockListViewModel(
            repository: mockRepository,
            coordinator: mockCoordinator
        )
        var subscriptions = Set<AnyCancellable>()

        let input = StockListViewModel.Input(
            didRefresh: PassthroughSubject<Void, Never>(),
            viewDidLoad: PassthroughSubject<Void, Never>(),
            togglePriceDiffFormat: PassthroughSubject<Void, Never>()
        )

        // Setup mock data
        let mockList = createMockList(
            name: "TestList", stockNos: ["2330", "2317"])
        mockRepository.mockStockList = [mockList]

        let mockStockInfo = OneDayStockInfo(msgArray: [
            OneDayStockInfoDetail(
                stockNo: "2330",
                open: "500",
                low: "495",
                high: "505",
                fullName: "台灣積體電路製造股份有限公司",
                current: "500",
                shortName: "台積電",
                yesterDayPrice: "490",
                time: "13:30:00"
            ),
            OneDayStockInfoDetail(
                stockNo: "2317",
                open: "100",
                low: "98",
                high: "102",
                fullName: "鴻海精密工業股份有限公司",
                current: "100",
                shortName: "鴻海",
                yesterDayPrice: "95",
                time: "13:30:00"
            ),
        ])
        mockRepository.mockOneDayStockInfo = mockStockInfo

        let output = sut.transform(input: input)
        var receivedStocks: [[StockCellViewModel]] = []

        output.stocks
            .sink { stocks in
                receivedStocks.append(stocks)
            }
            .store(in: &subscriptions)

        // When
        input.viewDidLoad.send()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // 搜尋台積電
        sut.searchText.send("2330")
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then
        let filteredStocks = receivedStocks.last
        assert(filteredStocks?.count == 1)
        assert(filteredStocks?[0].stockNo == "2330")
        assert(filteredStocks?[0].stockShortName == "台積電")
        assert(filteredStocks?[0].stockPrice == "500.00")
    }
}

extension TestStockListViewModel {
    private func createMockList(name: String, stockNos: [String] = [])
        -> MyTaiwanStock.ListStruct
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
        var createdStockNoStructs: [MyTaiwanStock.StockNoStruct] = []
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
            createdStockNoStructs.append(stockNoObject.toStruct())

        }

        try? context.save()
        if let listStruct = list.toStruct() {
            return listStruct
        } else {
            fatalError("Failed to convert List MO to ListStruct")
        }
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
    var mockStockList: [MyTaiwanStock.ListStruct] = []
    var mockOneDayStockInfo = OneDayStockInfo(msgArray: [])
    var fetchOneDayStockInfoCalled = false
    var lastFetchedStockList: [String] = []

    // MARK: - Core Methods Used in ViewModel
    func stockList() -> [MyTaiwanStock.ListStruct] {
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
        with stockNumber: String, currentFollowingList: MyTaiwanStock.ListStruct
    ) {
    }

    func deleteStockNumber(
        stockNoObject: MyTaiwanStock.StockNoStruct, listName: String,
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
    func deleteList(list: MyTaiwanStock.ListStruct) {}
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
