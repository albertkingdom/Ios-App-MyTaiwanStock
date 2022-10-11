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
    var context: NSManagedObjectContext?
    var localDB: LocalDBService!
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
    
    var onlineDBService: OnlineDBService?
    
    @Published var isLoading = false {
        didSet {
            print("isLoading \(isLoading)")
        }
    }
    
    init() {
        setupFetchStockInfo()
    }
    init(context: NSManagedObjectContext){
        setupFetchStockInfo()
        self.context = context
        onlineDBService = OnlineDBService(context: context)
    }
    
    
    func handleFetchListFromDB() -> Void {
        let listObjectFromDB = localDB.fetchAllListFromDB()

        if listObjectFromDB.isEmpty {
            // if no existing following list in db, create a default one
            guard let newList = localDB.saveNewListToDB(listName: "預設清單1") else { return }

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
                    //print(" \(stockNo)")
                    return stockNo
                }
                self?.stockNoStringCombine.send(stockNoStringArray)
            }.store(in: &subscription)
        
      
    
        
        stockNoStringCombine
            .removeDuplicates()
            .sink(receiveValue: { [unowned self] stockNos in
                //print("stockNos \(stockNos)")
                if stockNos.isEmpty {
                    self.stockCellDatasCombine.send([])
                    return
                }
                
               repeatFetch(stockNos: stockNos)
                
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
        OneDayStockInfo.fetchOneDayStockInfoCombine(stockList: stockNos)
        
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
                self?.localDB.updateStockNoInDBwithPrice(stockNos: stockNos, cellViewModels: cellVMs)
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
 
    func saveNewStockNumberToDB(stockNumber: String){
        if stockNameStringSetCombine.value.firstIndex(of: stockNumber) != nil { return }
        localDB.saveNewStockNumberToDB(stockNumber: stockNumber, currentFollowingList: currentFollowingListCombine.value!)
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
        
        localDB.deleteStockNumberInDB(stockNoObject: stockNoObjectToDel)
        // delete stockNo from online DB
        print("delete stockNo string \(itemToDelete.stockNo)")
        deleteStockNoFromOnlineDB(stockNo: itemToDelete.stockNo)
        
        
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

    
    //MARK: online DB
    func uploadNewStockNoToOnlineDB(stockNumber: String) {
        onlineDBService?.uploadNewStockNoToOnlineDB(stockNumber: stockNumber, listName: menuTitleCombine)
    }
    func deleteStockNoFromOnlineDB(stockNo: String) {
        onlineDBService?.deleteStockNoFromOnlineDB(stockNo: stockNo, listName: menuTitleCombine)
    }
    func getOnlineDBDataAndInsertLocal(completion: (() -> Void)?) {
      
        onlineDBService?.getAllListAndStocksFromOnlineDBAndSaveToLocal(completion: completion)
        onlineDBService?.getAllHistoryFromOnlineDBAndSaveToLocal()
    }
    func cancelTimer() {
        timer?.invalidate()
    }
    func setInitialMenuIndex(to index: Int) {
        lastTimeMenuIndex = index
    }
}

