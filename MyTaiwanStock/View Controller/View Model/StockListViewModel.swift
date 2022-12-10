//
//  StockListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//
import CoreData
import Foundation
import UIKit
import Combine

class StockListViewModel {

    private var timer: Timer?
    private var lastTimeMenuIndex = 0
    var stockNoStringCombine = CurrentValueSubject<[String], Never>([])

    var stockNameStringSetCombine = CurrentValueSubject<Set<String>,Never>([])

    var currentMenuIndexCombine = CurrentValueSubject<Int, Never>(0)
    
    @Published var menuTitleCombine: String = ""

    var menuActionsCombine = CurrentValueSubject<[UIAction], Never>([])
    
    private var followingListObjectFromDB: [List] = []

    private var currentFollowingListCombine = CurrentValueSubject<List?, Never>(nil)

    private var followingListSelectionMenuCombine = CurrentValueSubject<[String], Never>([])
    
    private var onedayStockInfo: [OneDayStockInfoDetail] = []
    
    private var stockCellDatasCombine = CurrentValueSubject<[StockCellViewModel], Never>([])
    
//    let filteredStockCellDatasCombine = CurrentValueSubject<[StockCellViewModel], Never>([])
    @Published var filteredStockCellDatasCombine: [StockCellViewModel] = []
    
    var dataForWidget = PassthroughSubject<Data, Never>()
        
    var searchText = CurrentValueSubject<String, Never>("")
    
    private var subscription = Set<AnyCancellable>()

    
    @Published var isLoading = false {
        didSet {
            print("isLoading \(isLoading)")
        }
    }
    
    let repository = RepositoryImpl()
    
    init() {
        setupFetchStockInfo()
    }
    
    
    func handleFetchListFromDB() -> Void {

        let listObjectFromDB = repository.stockList()
        if listObjectFromDB.isEmpty {
            // if no existing following list in db, create a default one

            let newList = repository.saveList(with:"預設清單1")
            self.followingListSelectionMenuCombine.send([newList.name!])
            self.followingListObjectFromDB.append(newList)
        }
        
        if !listObjectFromDB.isEmpty {

            let lists = listObjectFromDB.map({ list in
                list.name!
            })
            self.followingListSelectionMenuCombine.send(lists)
            self.followingListObjectFromDB = listObjectFromDB
        }
        self.currentMenuIndexCombine.send(lastTimeMenuIndex)
        setupStockNameStringSet()
        generateMenu()
    }
    
    private func setupFetchStockInfo() {

        currentMenuIndexCombine
            .sink { [unowned self] index in
                guard self.followingListObjectFromDB.count > 0 else { return }
                let list = self.followingListObjectFromDB[index]
   
                self.currentFollowingListCombine.send(list)
            }.store(in: &subscription)
        
        currentFollowingListCombine
            .sink { [weak self] list in
                guard let setOfStockNoObjects = list?.stockNo else { return }
                let stockNoStringArray:[String] = setOfStockNoObjects.map { ele -> String in
                    guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
                    return stockNo
                }
                self?.stockNoStringCombine.send(stockNoStringArray)
            }.store(in: &subscription)
        
      
    
        
        stockNoStringCombine
            //.removeDuplicates()
            .sink(receiveValue: { [unowned self] stockNos in
                if stockNos.isEmpty {
                    self.stockCellDatasCombine.send([])
                } else {
                    repeatFetch(stockNos: stockNos)
                }
            })
            .store(in: &subscription)
        
        
        stockCellDatasCombine
            .combineLatest(searchText)
            .map({ (cellDatas: [StockCellViewModel], text:String) -> [StockCellViewModel] in
                print("celldatas \(cellDatas) text \(text)")
                var output: [StockCellViewModel]
                if text.count > 0 {
                    output = cellDatas.filter { cellData in
                        cellData.stockNo.contains(text)
                    }

                }else {
                    output = cellDatas
                }
                return output

            })
            .assign(to: &$filteredStockCellDatasCombine)
//            .sink(receiveValue: { [weak self] cellDatas in
//                self?.filteredStockCellDatasCombine.send(cellDatas)
//            })
//            .store(in: &subscription)
    }
    private func generateMenu() {

        
        followingListSelectionMenuCombine
            .combineLatest(currentMenuIndexCombine)
            .sink(receiveValue: { [weak self] listNames, index in
                self?.menuTitleCombine = self?.followingListSelectionMenuCombine.value[index] ?? ""
                let actions = listNames.enumerated().map { index, str in
                    UIAction(title: str,
                             state: index == self?.currentMenuIndexCombine.value ? .on: .off,
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
        //print("repeatFetch \(stockNos)")

        timer?.invalidate()
        fetchStockInfo(stockNos: stockNos)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { [weak self] _ in
            self?.fetchStockInfo(stockNos: stockNos)
        })
    }
    private func fetchStockInfo(stockNos: [String]) {
        repository.fetchOneDayStockInfoCombine(stockList: stockNos)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    print("error \(error)")
                case .finished:
                    //print("finished")
                    break
                    
                    
                }
            } receiveValue: { [weak self] data in
                print("data \(data)")
                self?.onedayStockInfo = data.msgArray
                let cellVMs = data.msgArray.map { item in
                    StockCellViewModel(stock: item)
                }
                self?.stockCellDatasCombine.send(cellVMs)
                self?.repository.updateStockNoInDBwithPrice(stockNos: stockNos, cellViewModels: cellVMs)
            }
            .store(in: &self.subscription)
    }

    
    private func setupStockNameStringSet() {
        stockNameStringSetCombine.value.removeAll()
        currentFollowingListCombine.value = followingListObjectFromDB[currentMenuIndexCombine.value]
        //self.fetchStockNoFromDB()
        guard let setOfStockNoObjects = followingListObjectFromDB[currentMenuIndexCombine.value].stockNo else { return }
        let stockNoStringArray:[String] = setOfStockNoObjects.map { ele -> String in
            guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
            //print(" \(stockNo)")
            return stockNo
        }
        //print("stockNoStringArray \(stockNoStringArray)")
        stockNameStringSetCombine.send(Set(stockNoStringArray))
    }
 
    
    func deleteStockNumber(at index: Int) {
        let itemToDelete = stockCellDatasCombine.value[index]
        // find the stockNo object to be deleted
        guard let stockNoSet = currentFollowingListCombine.value?.stockNo else { return }
        
        let stockNoObjectArray = stockNoSet.map({ ele -> StockNo in
            let stockNoObject = ele as! StockNo
            return stockNoObject
        })
        let stockNoObjectToDel = stockNoObjectArray[index]
        

        // delete stockNo from online DB
        print("delete stockNo string \(itemToDelete.stockNo)")

        repository.deleteStockNumber(stockNoObject: stockNoObjectToDel, listName: menuTitleCombine, stockNumber: itemToDelete.stockNo
        )
        
        onedayStockInfo = onedayStockInfo.filter({
            $0.stockNo != itemToDelete.stockNo
        })


        stockCellDatasCombine.value = stockCellDatasCombine.value.filter({
            $0.stockNo != itemToDelete.stockNo
        })

        stockNameStringSetCombine.value = stockNameStringSetCombine.value.filter { stockNo in
            itemToDelete.stockNo != stockNo
        }// edit current stockno list
        
        stockNoStringCombine.value = stockNoStringCombine.value.filter({ stockNo in
            itemToDelete.stockNo != stockNo
        })
    }

    
    
    func saveNewStockNo(stockNumber: String) {
        if stockNameStringSetCombine.value.firstIndex(of: stockNumber) != nil { return }
        repository.saveStockNumber(with: stockNumber, currentFollowingList: currentFollowingListCombine.value!)
    }
    
    //MARK: online DB
    func getOnlineDBDataAndInsertLocal(completion: (() -> Void)?) {
        repository.getAllListAndStocksFromOnlineDBAndSaveToLocal(completion: completion)
        repository.getAllHistoryFromOnlineDBAndSaveToLocal()
    }
    func cancelTimer() {
        timer?.invalidate()
    }
    func setInitialMenuIndex(to index: Int) {
        lastTimeMenuIndex = index
    }
}

