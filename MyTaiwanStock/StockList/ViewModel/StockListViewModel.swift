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
    var stockNameString: Set<String> {
        print("\(stockNameStringSetCombine.value)")
        return stockNameStringSetCombine.value
    }
    var currentMenuIndex = CurrentValueSubject<Int, Never>(0)

    var menuTitleCombine = CurrentValueSubject<String, Never>("")

    var menuActionsCombine = CurrentValueSubject<[UIAction], Never>([])

    private var followingListObjectFromDB: [List] = []

    private var currentFollowingListCombine = CurrentValueSubject<List?, Never>(
        nil)

    private var followingListNames = CurrentValueSubject<
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

    struct Input {
        var didRefresh: PassthroughSubject<Void, Never>
        var viewDidLoad: PassthroughSubject<Void, Never>
        //        var tapFloatingButton: PassthroughSubject<Void, Never>
    }
    struct Output {
        var stocks: AnyPublisher<[StockCellViewModel], Never>
        var isLoading: AnyPublisher<Bool, Never>
        var menuTitle: AnyPublisher<String, Never>
    }
    func transform(input: Input) -> Output {
        input
            .didRefresh
            .print("did refresh triggr")
            .sink { _ in
                //guard let self = self else { return }
                let currentStockNos = Array(self.stockNameString)

                self.repeatFetch(stockNos: currentStockNos)
            }
            .store(in: &subscription)

        input.viewDidLoad
            .flatMap { _ -> AnyPublisher<[List]?, Never> in
                return Just(self.fetchListFromDB()).eraseToAnyPublisher()
            }
            .sink { [weak self] listObjectFromDB in
                guard let self = self else { return }
                if let listObjectFromDB {

                    self.followingListObjectFromDB = listObjectFromDB
                    let listNames = listObjectFromDB.compactMap {
                        $0.name
                    }
                    self.followingListNames.send(listNames)
                    let savedIndex = self.getSavedListIndex()
                    let index = min(savedIndex, listNames.count - 1)
                    let validIndex = max(0, index)
                    self.currentMenuIndex.send(validIndex)
                }
                self.isLoading = false
                self.shouldShowAlert = false
            }
            .store(in: &subscription)
        // 產生menu選單
        followingListNames
            .combineLatest(currentMenuIndex)
            .filter { listNames, _ in
                !listNames.isEmpty && !listNames.contains { $0.isEmpty }
            }
            .removeDuplicates(by: { prev, current in
                let (prevNames, prevIndex) = prev
                let (currentNames, currentIndex) = current
                return prevNames == currentNames && prevIndex == currentIndex
            })
            .sink(receiveValue: { [weak self] listNames, index in
                let title = listNames[min(listNames.count - 1, index)]
                guard !title.isEmpty else { return }
                self?.menuTitleCombine.send(title)

                let actions = listNames.enumerated().map { index, str in
                    UIAction(
                        title: str,
                        state: index == self?.currentMenuIndex.value
                            ? .on : .off,
                        handler: { action in
                            self?.currentMenuIndex.send(index)
                            self?.setupStockNameStringSet()
                        })
                }
                self?.menuActionsCombine.send(actions)
            })
            .store(in: &subscription)

        return Output(
            stocks: filteredStockCellDatasCombine.eraseToAnyPublisher(),
            isLoading: $isLoading.eraseToAnyPublisher(),
            menuTitle: menuTitleCombine.eraseToAnyPublisher()
        )
    }
    private func fetchListFromDB() -> [List]? {
        let listObjectFromDB = repository.stockList()
        return listObjectFromDB.isEmpty ? nil : listObjectFromDB
    }

    private func setupFetchStockInfo() {

        currentMenuIndex
            //  Handle Timer/List Side Effects in handleEvents
            .handleEvents(receiveOutput: { [weak self] index in
                guard let self = self else { return }
                self.timer?.invalidate()
                let list: List?
                if self.followingListObjectFromDB.count > index
                    && self.followingListObjectFromDB.count > 0
                {
                    list = self.followingListObjectFromDB[index]
                } else {
                    list = nil
                }
                self.currentFollowingListCombine.send(list)
            })
            .compactMap { [weak self] index -> List? in
                guard let self = self,
                    self.followingListObjectFromDB.count > index,
                    self.followingListObjectFromDB.count > 0
                else {
                    // 如果索引無效或數據庫為空，則這裡返回 nil，compactMap 會過濾掉
                    return nil
                }
                return self.followingListObjectFromDB[index]
            }
            .map { list -> [String] in
                guard let setOfStockNoObjects = list?.stockNo else {
                    return []
                }
                return setOfStockNoObjects.compactMap {
                    ($0 as? StockNo)?.stockNo
                }
            }
            .sink { [weak self] stockNos in
                guard let self else { return }
                logger.debug("stockNos \(stockNos)")
                self.stockNameStringSetCombine.send(Set(stockNos))

                if !stockNos.isEmpty {
                    self.repeatFetch(stockNos: stockNos)
                } else {
                    self.filteredStockCellDatasCombine.send([])
                }
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

    func repeatFetch(stockNos: [String]) {
        logger.debug("取消timer and stockNos \(stockNos)")
        timer?.invalidate()
        if stockNos.isEmpty {
            self.isLoading = false
            return
        }
        fetchStockInfo(stockNos: Array(stockNos))
        logger.debug("建立timer and stockNos \(stockNos)")
        timer = Timer.scheduledTimer(
            withTimeInterval: 60, repeats: true,
            block: { [weak self, stockNos] _ in
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
                guard let self = self else { return }

                self.onedayStockInfo = data.msgArray
                let cellVMs = data.msgArray.map { item in
                    StockCellViewModel(stock: item)
                }
                self.stockCellDatasCombine.send(cellVMs)
                //                self.repository.updateStockNoInDBwithPrice(
                //                    stockNos: stockNos, cellViewModels: cellVMs)
                //self.isLoading = false
            }
            .store(in: &self.subscription)
    }

    private func setupStockNameStringSet() {
        guard
            let setOfStockNoObjects = followingListObjectFromDB[
                currentMenuIndex.value
            ].stockNo
        else { return }
        let stockNoStringArray: [String] = setOfStockNoObjects.map {
            ele -> String in
            guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
            //print(" \(stockNo)")
            return stockNo
        }
        //print("stockNoStringArray \(stockNoStringArray)")
        stockNameStringSetCombine.send(Set(stockNoStringArray))  // CHANGE: use send() instead of direct assignment

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
            stockNoObject: stockNoObjectToDel, listName: menuTitleCombine.value,
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
        //        handleFetchListFromDB()
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
            currentMenuIndex.value, forKey: UserDefaults.menuIndex)
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
            listName: menuTitleCombine.value,
            addNewStockToDB: saveNewStockNo
        )
    }

}
