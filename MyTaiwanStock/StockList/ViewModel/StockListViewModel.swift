//
//  StockListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//
import Combine
import CoreData
import Foundation
import UIKit
import WidgetKit

class StockListViewModel: ObservableObject {
    private var timer: Timer?
    private var lastTimeMenuIndex = 0

    var stockNameStringSetCombine = CurrentValueSubject<Set<String>, Never>([])

    var currentMenuIndexCombine = CurrentValueSubject<Int, Never>(0)

    @Published var menuTitleCombine: String = ""

    var menuActionsCombine = CurrentValueSubject<[UIAction], Never>([])

    private var followingListObjectFromDB: [List] = []

    private var currentFollowingListCombine = CurrentValueSubject<List?, Never>(
        nil)

    private var followingListSelectionMenuCombine = CurrentValueSubject<
        [String], Never
    >([])

    private var onedayStockInfo: [OneDayStockInfoDetail] = []

    private var stockCellDatasCombine = CurrentValueSubject<
        [StockCellViewModel], Never
    >([])

    var filteredStockCellDatasCombine = CurrentValueSubject<
        [StockCellViewModel], Never
    >([])

    var dataForWidget = PassthroughSubject<Data, Never>()

    var searchText = CurrentValueSubject<String, Never>("")

    private var subscription = Set<AnyCancellable>()
    var userDefault = UserDefaults(suiteName: "group.a2006mike.myTaiwanStock")

    @Published var isLoading = true {
        didSet {
            print("isLoading \(isLoading)")
        }
    }
    @Published var shouldShowAlert = false {
        didSet {
            print("showTip \(shouldShowAlert)")
        }
    }
    private let repository: any NetworkService
    private let coordinator: StockListCoordinatorProtocol

    init(
        repository: any NetworkService,
        coordinator: StockListCoordinatorProtocol
    ) {
        self.repository = repository
        self.coordinator = coordinator
        setupFetchStockInfo()
    }
    @objc func handleInitialDataUpdate() {
        logger.debug("完成core data 同步")
        handleFetchListFromDB()
    }
    struct Input {
        var didRefresh: PassthroughSubject<Void, Never>
    }
    struct Output {
        var stocks: AnyPublisher<[StockCellViewModel], Never>
        var isLoading: AnyPublisher<Bool, Never>

    }
    func transform(input: Input) -> Output {
        input
            .didRefresh
            .sink { [weak self] _ in
                guard let self = self else { return }
                let currentStockNos = Array(
                    self.stockNameStringSetCombine.value)

                self.repeatFetch(stockNos: currentStockNos)
            }
            .store(in: &subscription)
        return Output(
            stocks: filteredStockCellDatasCombine.eraseToAnyPublisher(),
            isLoading: $isLoading.eraseToAnyPublisher()
        )
    }
    func fetchListFromDB() -> [List]? {
        let listObjectFromDB = repository.stockList()
        return listObjectFromDB.isEmpty ? nil : listObjectFromDB
    }

    fileprivate func prepareData(_ listObjectFromDB: [List]) {
        logger.debug("core data有資料")
        let lists = listObjectFromDB.compactMap({ list in
            list.name
        })
        logger.debug("lists \(lists)")
        let savedIndex = getSavedListIndex()
        let validIndex = min(savedIndex, listObjectFromDB.count - 1)

        self.followingListSelectionMenuCombine.send(lists)
        self.followingListObjectFromDB = listObjectFromDB

        self.currentMenuIndexCombine.send(validIndex)

        generateMenu()
        isLoading = false
        shouldShowAlert = false
    }

    func handleFetchListFromDB() -> Bool {

        guard let listObjectFromDB = fetchListFromDB() else {
            logger.debug("core data有資料")
            isLoading = false
            shouldShowAlert = false
            return false
        }
        prepareData(listObjectFromDB)
        return true
    }

    private func setupFetchStockInfo() {
        stockNameStringSetCombine
            .sink { stockNos in
                logger.debug("🔍 stockNameStringSetCombine changed: \(stockNos)")
            }
            .store(in: &subscription)
        currentMenuIndexCombine
            .map { [unowned self] index -> List? in
                timer?.invalidate()
                guard self.followingListObjectFromDB.count > 0 else {
                    return nil
                }
                let list = self.followingListObjectFromDB[index]
                return list
            }
            .handleEvents(receiveOutput: { [unowned self] list in
                self.currentFollowingListCombine.send(list)  // Maintain external access
            })
            .compactMap { list -> [String] in
                guard let setOfStockNoObjects = list?.stockNo else { return [] }
                return setOfStockNoObjects.compactMap {
                    ($0 as? StockNo)?.stockNo
                }
            }
            .filter { !$0.isEmpty }
            .sink { [unowned self] stockNos in
                logger.debug("stockNos \(stockNos)")
                self.stockNameStringSetCombine.send(Set(stockNos))
                self.repeatFetch(stockNos: stockNos)
            }
            .store(in: &subscription)

        stockCellDatasCombine
            .combineLatest(searchText)
            .map({
                (cellDatas: [StockCellViewModel], text: String)
                    -> [StockCellViewModel] in
                text.isEmpty
                    ? cellDatas.sorted { $0.stockNo < $1.stockNo }
                    : cellDatas.filter { $0.stockNo.contains(text) }.sorted {
                        $0.stockNo < $1.stockNo
                    }
            })
            .sink(receiveValue: { [weak self] cellData in
                self?.filteredStockCellDatasCombine.send(cellData)
            })
            .store(in: &subscription)
    }
    private func generateMenu() {

        followingListSelectionMenuCombine
            .combineLatest(currentMenuIndexCombine)
            .sink(receiveValue: { [weak self] listNames, index in
                self?.menuTitleCombine =
                    self?.followingListSelectionMenuCombine.value[index] ?? ""
                let actions = listNames.enumerated().map { index, str in
                    UIAction(
                        title: str,
                        state: index == self?.currentMenuIndexCombine.value
                            ? .on : .off,
                        handler: { action in

                            self?.currentMenuIndexCombine.send(index)
                            self?.setupStockNameStringSet()

                        })
                }
                self?.menuActionsCombine.send(actions)

            })
            .store(in: &subscription)

    }
    func repeatFetch(stockNos: [String]) {
        logger.debug("取消timer")
        timer?.invalidate()
        if stockNos.isEmpty { return }
        fetchStockInfo(stockNos: Array(stockNos))
        logger.debug("建立timer")
        timer = Timer.scheduledTimer(
            withTimeInterval: 60, repeats: true,
            block: { [weak self] _ in
                self?.fetchStockInfo(stockNos: Array(stockNos))
            })
    }
    private func fetchStockInfo(stockNos: [String]) {
        repository.fetchOneDayStockInfoCombine(stockList: stockNos)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                switch completion {
                case .failure(let error):
                    print("請求台股資料錯誤 \(error)")
                    let stockCellViewModels = stockNos.map {
                        StockCellViewModel(stockNo: $0)
                    }
                    self.stockCellDatasCombine.send(stockCellViewModels)
                case .finished:
                    //print("finished")
                    break

                }
            } receiveValue: { [weak self] data in
                //                print("data \(data)")
                guard let self = self else { return }

                self.onedayStockInfo = data.msgArray
                let cellVMs = data.msgArray.map { item in
                    StockCellViewModel(stock: item)
                }
                self.stockCellDatasCombine.send(cellVMs)
                self.repository.updateStockNoInDBwithPrice(
                    stockNos: stockNos, cellViewModels: cellVMs)
                self.isLoading = false
            }
            .store(in: &self.subscription)
    }

    private func setupStockNameStringSet() {
        stockNameStringSetCombine.value.removeAll()
        guard
            let setOfStockNoObjects = followingListObjectFromDB[
                currentMenuIndexCombine.value
            ].stockNo
        else { return }
        let stockNoStringArray: [String] = setOfStockNoObjects.map {
            ele -> String in
            guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
            //print(" \(stockNo)")
            return stockNo
        }
        //print("stockNoStringArray \(stockNoStringArray)")
        self.userDefault?.setValue(stockNoStringArray, forKey: "stockNos")
    }

    func deleteStockNumber(stockNo: String) {
        guard
            let index = stockCellDatasCombine.value.firstIndex(where: {
                $0.stockNo == stockNo
            })
        else { return }
        let itemToDelete = stockCellDatasCombine.value[index]
        // find the stockNo object to be deleted
        guard let stockNoSet = currentFollowingListCombine.value?.stockNo else {
            return
        }

        let stockNoObjectArray = stockNoSet.map({ ele -> StockNo in
            let stockNoObject = ele as! StockNo
            return stockNoObject
        })
        let stockNoObjectToDel = stockNoObjectArray[index]

        // delete stockNo from online DB
        print("delete stockNo string \(itemToDelete.stockNo)")

        repository.deleteStockNumber(
            stockNoObject: stockNoObjectToDel, listName: menuTitleCombine,
            stockNumber: itemToDelete.stockNo
        )

        onedayStockInfo = onedayStockInfo.filter({
            $0.stockNo != itemToDelete.stockNo
        })

        stockCellDatasCombine.value = stockCellDatasCombine.value.filter({
            $0.stockNo != itemToDelete.stockNo
        })

        stockNameStringSetCombine.value = stockNameStringSetCombine.value.filter
        { stockNo in
            itemToDelete.stockNo != stockNo
        }  // edit current stockno list

        // Create a new fetch with updated stock list
        let updatedStockNos = Array(stockNameStringSetCombine.value)
        repeatFetch(stockNos: updatedStockNos)
    }

    func saveNewStockNo(stockNumber: String) {
        if stockNameStringSetCombine.value.firstIndex(of: stockNumber) != nil {
            return
        }
        repository.saveStockNumber(
            with: stockNumber,
            currentFollowingList: currentFollowingListCombine.value!)
        handleFetchListFromDB()
    }

    //MARK: online DB
    func getOnlineDBDataAndInsertLocal(completion: (() -> Void)?) {
        repository.getAllListAndStocksFromOnlineDBAndSaveToLocal(
            completion: completion)
        repository.getAllHistoryFromOnlineDBAndSaveToLocal()
    }
    func cancelTimer() {
        timer?.invalidate()
    }
    func setInitialMenuIndex(to index: Int) {
        lastTimeMenuIndex = index
    }

    func saveCurrentListIndex() {
        UserDefaults.standard.set(
            currentMenuIndexCombine.value, forKey: UserDefaults.menuIndex)
    }

    // 新增：從 UserDefaults 獲取儲存的索引
    func getSavedListIndex() -> Int {
        return UserDefaults.standard.integer(forKey: UserDefaults.menuIndex)
    }

}

extension StockListViewModel {
    func navigateToStockDetail(
        stockNo: String, currentStockPrice: String, stockName: String,
        stockPriceDiff: String, timeString: String
    ) {
        coordinator.showStockDetail(
            stockNo: stockNo,
            currentStockPrice: currentStockPrice,
            stockName: stockName,
            stockPriceDiff: stockPriceDiff,
            timeString: timeString
        )
    }

    func navigateToAddList() {
        coordinator.showAddList()
    }

    func navigateToAddStock() {
        coordinator.showAddStock(
            followingStockNoList: stockNameStringSetCombine.value,
            listName: menuTitleCombine,
            addNewStockToDB: saveNewStockNo
        )
    }

}
