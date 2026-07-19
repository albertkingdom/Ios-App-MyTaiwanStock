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
import ActivityKit

class StockListViewModel: ObservableObject {
    private var timer: Timer?
    private var lastTimeMenuIndex = 0
    private var priceDiffFormat = CurrentValueSubject<
        StockCellViewModel.PriceDiffFormat, Never
    >(.Digit)

    private var lastFetchTime: String?
    private var staleTimeCount = 0

    var stockNameStringSetCombine = CurrentValueSubject<Set<String>, Never>([])
    var stockNameString: Set<String> {
        print("\(stockNameStringSetCombine.value)")
        return stockNameStringSetCombine.value
    }
    var currentMenuIndex = CurrentValueSubject<Int, Never>(0)

    var menuTitleCombine = CurrentValueSubject<String, Never>("")

    var menuActionsCombine = CurrentValueSubject<[UIAction], Never>([])

    private var followingListObjectFromDB: [ListStruct] = []

    private var currentFollowingListCombine = CurrentValueSubject<
        ListStruct?, Never
    >(
        nil)

    private var followingListNames = CurrentValueSubject<
        [String], Never
    >([])

    var listNames: [String] {
        return self.followingListNames.value
    }

    private var onedayStockInfo: [OneDayStockInfoDetail] = []

    var stockCellDatasCombine = CurrentValueSubject<
        [StockCellViewModel], Never
    >([])

    var filteredStockCellDatasCombine = PassthroughSubject<
        [StockCellViewModel], Never
    >()

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
        var togglePriceDiffFormat: PassthroughSubject<Void, Never>
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
            .flatMap { _ -> AnyPublisher<[ListStruct]?, Never> in
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

                var actions = listNames.enumerated().map { index, str in
                    UIAction(
                        title: str,
                        state: index == self?.currentMenuIndex.value
                            ? .on : .off,
                        handler: { action in
                            self?.currentMenuIndex.send(index)
                            self?.setupStockNameStringSet()
                        })
                }
                actions.append(
                    UIAction(
                        title: "編輯",
                        handler: { [weak self] action in
                            self?.navigateToAddList()
                        })
                )
                self?.menuActionsCombine.send(actions)
            })
            .store(in: &subscription)

        input.togglePriceDiffFormat
            .sink { [weak self] (_) in
                guard let self else { return }
                if priceDiffFormat.value == .Digit {
                    priceDiffFormat.send(.Percentage)
                } else {
                    priceDiffFormat.send(.Digit)
                }

            }
            .store(in: &subscription)

        return Output(
            stocks: filteredStockCellDatasCombine.eraseToAnyPublisher(),
            isLoading: $isLoading.eraseToAnyPublisher(),
            menuTitle: menuTitleCombine.eraseToAnyPublisher()
        )
    }
    private func fetchListFromDB() -> [ListStruct]? {
        let listObjectFromDB = repository.stockList()
        return listObjectFromDB.isEmpty ? nil : listObjectFromDB
    }

    private func setupFetchStockInfo() {

        currentMenuIndex
            //  Handle Timer/List Side Effects in handleEvents
            .handleEvents(receiveOutput: { [weak self] index in
                guard let self = self else { return }
                self.timer?.invalidate()
                let list: ListStruct?
                if self.followingListObjectFromDB.count > index
                    && self.followingListObjectFromDB.count > 0
                {
                    list = self.followingListObjectFromDB[index]
                } else {
                    list = nil
                }
                self.currentFollowingListCombine.send(list)
            })
            .compactMap { [weak self] index -> ListStruct? in
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
                let setOfStockNoObjects = list.stockNos
                return setOfStockNoObjects.compactMap {
                    $0.stockNo
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
            .combineLatest(searchText, priceDiffFormat)
            .dropFirst()
            .print("改變了-")
            .map({
                (cellDatas: [StockCellViewModel], text: String, desiredFormat)
                    -> [StockCellViewModel] in
                let filteredCellDatas =
                    text.isEmpty
                    ? cellDatas.sorted { $0.stockNo < $1.stockNo }
                    : cellDatas.filter { $0.stockNo.contains(text) }.sorted {
                        $0.stockNo < $1.stockNo
                    }
                let updatedViewModels = filteredCellDatas.map { viewModel in
                    var mutableViewModel = viewModel  // struct 會進行值複製，所以是新的 ViewModel
                    mutableViewModel.priceDiffFormat = desiredFormat  // 將外部訊號的格式設定到 View Model 內部
                    return mutableViewModel  // 返回修改後的 ViewModel
                }
                return updatedViewModels
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
            .map { stockInfo -> [OneDayStockInfoDetail] in
                self.onedayStockInfo = stockInfo.msgArray
                return stockInfo.msgArray
            }
            .flatMap { stockInfoDetails -> AnyPublisher<[StockCellViewModel], Error> in
                // 建立一個映射，用於快速查找股票資訊
                let stockInfoMap = Dictionary(
                    uniqueKeysWithValues: stockInfoDetails.map { ($0.stockNo, $0) }
                )
                
                // 根據傳入的 stockNos 順序建立 ViewModel
                let cellVMs = stockNos.map { stockNo -> StockCellViewModel in
                    if let stockInfo = stockInfoMap[stockNo] {
                        return StockCellViewModel(
                            stock: stockInfo,
                            priceDiffInPercentage: self.priceDiffFormat.value
                        )
                    } else {
                        // 如果找不到股票資訊，創建一個空的 ViewModel
                        return StockCellViewModel(stockNo: stockNo)
                    }
                }
                return Just(cellVMs)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
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
                    break
                }
            } receiveValue: { [weak self] cellVMs in
                guard let self = self else { return }
                self.stockCellDatasCombine.send(cellVMs)

                if #available(iOS 16.1, *) {
                    self.updateLiveActivityIfNeeded()
                    self.checkMarketClose()
                }
            }
            .store(in: &self.subscription)
    }

    private func setupStockNameStringSet() {

        let setOfStockNoObjects = followingListObjectFromDB[
            currentMenuIndex.value
        ].stockNos

        let stockNoStringArray: [String] = setOfStockNoObjects.map {
            ele -> String in
            guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
            //print(" \(stockNo)")
            return stockNo
        }
        //print("stockNoStringArray \(stockNoStringArray)")
        stockNameStringSetCombine.send(Set(stockNoStringArray))  // CHANGE: use send() instead of direct assignment

        self.userDefault?.setValue(stockNoStringArray, forKey: "stockNos")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteStockNumber(stockNo: String) {
        guard
            let stockIndex = stockCellDatasCombine.value.firstIndex(where: {
                $0.stockNo == stockNo
            })
        else { return }
        // find the stockNo object to be deleted
        guard let stockNoSet = currentFollowingListCombine.value?.stockNos
        else {
            return
        }
        
        
        let stockNoObjectToDel = stockNoSet[stockIndex]

        // delete stockNo from online DB
        print("delete stockNo string \(stockNo)")
        let currentIndex = currentMenuIndex.value
        guard currentIndex < followingListObjectFromDB.count else { return }
      
        
        repository.deleteStockNumber(
            stockNoObject: stockNoObjectToDel,
            listName: menuTitleCombine.value,
            stockNumber: stockNo
        )
        followingListObjectFromDB[currentIndex].stockNos = followingListObjectFromDB[currentIndex]
            .stockNos.filter { $0.stockNo != stockNo }
        
        onedayStockInfo = onedayStockInfo.filter({
            $0.stockNo != stockNo
        })

        stockCellDatasCombine.value = stockCellDatasCombine.value.filter({
            $0.stockNo != stockNo
        })

        stockNameStringSetCombine.value = stockNameStringSetCombine.value.filter{ $0 != stockNo }  // edit current stockno list

        // Update App Group + refresh widget
        let updatedStockNos = Array(stockNameStringSetCombine.value)
        self.userDefault?.setValue(updatedStockNos, forKey: "stockNos")
        WidgetCenter.shared.reloadAllTimelines()

        repeatFetch(stockNos: updatedStockNos)
    }

    func saveNewStockNo(stockNumber: String) {
        if stockNameStringSetCombine.value.firstIndex(of: stockNumber) != nil {
            return
        }
        repository.saveStockNumber(
            with: stockNumber,
            currentFollowingList: currentFollowingListCombine.value!)
        stockNameStringSetCombine.value = stockNameStringSetCombine.value.union([stockNumber])
        let updatedStockNos = Array(stockNameStringSetCombine.value)
        self.userDefault?.setValue(updatedStockNos, forKey: "stockNos")
        WidgetCenter.shared.reloadAllTimelines()

        repeatFetch(stockNos: updatedStockNos)
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

    @available(iOS 16.1, *)
    private func updateLiveActivityIfNeeded() {
        let trackedStockNo = ActivityManager.shared.trackedStockNo
        guard let trackedStockNo = trackedStockNo else { return }

        guard let stockInfo = onedayStockInfo.first(where: { $0.stockNo == trackedStockNo }) else {
            return
        }

        let priceChange: String
        let priceChangePercent: String
        let yesterDayPrice: String

        if let currentFloat = Float(stockInfo.current),
           let yesterDayFloat = Float(stockInfo.yesterDayPrice) {
            let diff = currentFloat - yesterDayFloat
            priceChange = diff >= 0 ? String(format: "+%.2f", diff) : String(format: "%.2f", diff)
            yesterDayPrice = String(format: "%.2f", yesterDayFloat)

            if yesterDayFloat != 0 {
                let pct = (diff / yesterDayFloat) * 100
                priceChangePercent = pct >= 0 ? String(format: "+%.3f%%", pct) : String(format: "%.3f%%", pct)
            } else {
                priceChangePercent = "0.000%"
            }
        } else {
            return
        }

        ActivityManager.shared.update(
            currentPrice: stockInfo.current,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
            yesterDayPrice: yesterDayPrice,
            time: stockInfo.time)
    }

    @available(iOS 16.1, *)
    private func checkMarketClose() {
        guard let trackedStockNo = ActivityManager.shared.trackedStockNo else { return }

        let calendar = Calendar.current
        let taiwanTimeZone = TimeZone(identifier: "Asia/Taipei")!
        let now = Date()
        let components = calendar.dateComponents(in: taiwanTimeZone, from: now)

        guard let hour = components.hour,
              let minute = components.minute else { return }

        let totalMinutes = hour * 60 + minute
        guard totalMinutes >= (13 * 60 + 30) else {
            staleTimeCount = 0
            lastFetchTime = nil
            return
        }

        let latestTime = onedayStockInfo.first(where: { $0.stockNo == trackedStockNo })?.time
        if let lastTime = lastFetchTime, let latestTime = latestTime, lastTime == latestTime {
            staleTimeCount += 1
            if staleTimeCount >= 2 {
                ActivityManager.shared.end()
                staleTimeCount = 0
                lastFetchTime = nil
            }
        } else {
            staleTimeCount = 1
            lastFetchTime = latestTime
        }
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
