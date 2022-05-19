//
//  StockListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//
import CoreData
import Foundation
import UIKit

class StockListViewModel {
    var context: NSManagedObjectContext?
    
    var stockNameStringSet = Observable<Set<String>>(nil)
    var currentMenuIndex = 0
    var menuTitle = Observable<String>("")
    var menuActions = Observable<[UIAction]>([])
    var followingListObjectFromDB: [List] = []
    var currentFollowingList = Observable<List>(nil)
    var followingListSelectionMenu = Observable<[String]>([])
    var onedayStockInfo: [OneDayStockInfoDetail] = [] {
        didSet {
            transformForWidget()
        }
    }
    var stockCellDatas = Observable<[StockCellViewModel]>([])
    var dataForWidget = Observable<Data>(nil)
    
    func fetchAllListFromDB() -> [List]{
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        var lists: [List] = []
        do {
            guard let result = try context?.fetch(fetchRequest) else { return [List]() }
            //print("lists \(result)")

            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    
    func handleFetchListFromDB() {
        let listObjectFromDB = fetchAllListFromDB()
        //print("listObjectFromDB \(listObjectFromDB)")
        if listObjectFromDB.isEmpty {
            // if no existing following list in db, create a default one
            guard let newList = saveNewListToDB(listName: "預設清單1") else { return }
            self.followingListSelectionMenu.value = [newList.name!]
            self.followingListObjectFromDB.append(newList)
            self.currentMenuIndex = 0
        }
        if !listObjectFromDB.isEmpty {
            self.followingListSelectionMenu.value = listObjectFromDB.map({ list in
                list.name!
            })
            self.followingListObjectFromDB = listObjectFromDB
            
            self.currentMenuIndex = 0
            
            
        }
        setupStockNameStringSet()
        generateMenu()
    }
    func generateMenu() {
//        if #available(iOS 15, *) {
        //        } else {
        //            menuTitle.value = self.followingListSelectionMenu.value?[currentMenuIndex.value!]
        //        }
        menuTitle.value = self.followingListSelectionMenu.value?[currentMenuIndex]
        var actions = followingListSelectionMenu.value?.enumerated().map { index, str in
            UIAction(title: str, state: index == currentMenuIndex ? .on: .off, handler: { action in
                
                self.currentMenuIndex = index
                self.setupStockNameStringSet()
                //                if #available(iOS 15, *) {
                //                } else {
                //                    self.menuTitle.value = str
                //                }
                self.menuTitle.value = str
            })
        }
        menuActions.value = actions
    }
    
    
    func fetchOneDayStockInfoFromAPI() {
        //guard let stockNoList = fetchedResultsController.fetchedObjects else { return }
        let stockNoListArray = Array(stockNameStringSet.value!)
        
        OneDayStockInfo.fetchOneDayStockInfo(stockList: stockNoListArray ){ result in
            switch result {
            case .success(let stockInfo):
                //print("success: \(stockInfo)")
                self.onedayStockInfo = stockInfo.msgArray
                
                
                self.stockCellDatas.value = self.onedayStockInfo.map { item in
                    StockCellViewModel(stock: item)
                }
                
      
            case .failure(let error):
                print("failure: \(error)")
            }
        }
    }
    
    func setupStockNameStringSet() {
        stockNameStringSet.value?.removeAll()
        currentFollowingList.value = followingListObjectFromDB[currentMenuIndex]
        //self.fetchStockNoFromDB()
        guard let setOfStockNoObjects = followingListObjectFromDB[currentMenuIndex].stockNo else { return }
        let stockNoStringArray:[String] = setOfStockNoObjects.map { ele -> String in
            guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
            //print(" \(stockNo)")
            return stockNo
        }
        //print("stockNoStringArray \(stockNoStringArray)")
        stockNameStringSet.value = Set(stockNoStringArray)
    }
    // MARK: Core Data - save
    func saveNewStockNumberToDB(stockNumber: String) {
        //print("saveNewStockNumberToDB...\(stockNumber)")
        guard let context = self.context else { return }

        if stockNameStringSet.value?.firstIndex(of: stockNumber) != nil { return }
        let newStockNo = StockNo(context: context)
        newStockNo.stockNo = stockNumber
        newStockNo.ofList = currentFollowingList.value // set the relationship between list and stockNo
        //lists[currentMenuIndex].stockNo = NSSet(array: [newStockNo])
        do {
            try context.save()
        } catch {
            print("error, \(error.localizedDescription)")
        }
 
    }
    
    func deleteStockNumber(at index: Int) {
        guard let itemToDelete = stockCellDatas.value?[index] else { return }
        // find the stockNo object to be deleted
        guard let stockNoSet = currentFollowingList.value?.stockNo else { return }
        
        let stockNoObjectArray = stockNoSet.map({ ele -> StockNo in
            let stockNoObject = ele as! StockNo
            return stockNoObject
        })
        let stockNoObjectToDel = stockNoObjectArray[index]
        
        deleteStockNumberInDB(stockNoObject: stockNoObjectToDel)
        
        onedayStockInfo = onedayStockInfo.filter({
            $0.stockNo != itemToDelete.stockNo
        })

        stockCellDatas.value = stockCellDatas.value?.filter({
            $0.stockNo != itemToDelete.stockNo
        })
        
        stockNameStringSet.value = stockNameStringSet.value?.filter { stockNo in
            itemToDelete.stockNo != stockNo
        } // edit current stockno list
    }
    // MARK: Core Data - delete
    func deleteStockNumberInDB(stockNoObject: StockNo) {
        context?.delete(stockNoObject)
        
        let result = checkIfRemainingStockNoObject(with: stockNoObject.stockNo!)
        
        if !result {
            deleteHistory(with: stockNoObject.stockNo!)
        }
        // TODO: show the UIAlert
        try? context?.save()

    }
    func checkIfRemainingStockNoObject(with stockNo: String) -> Bool {
        let fetchStockRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchStockRequest.predicate = predicate
        
        if let stockNoObjects = try? context?.fetch(fetchStockRequest) {
  
            if stockNoObjects.isEmpty {
                // there's no stockNo object with same stockNo
                return false
            }
            
        }
        return true
    }
    
    func deleteHistory(with stockNo: String) {
        // fetch history with stockNo, then delete them
        let fetchHistoryRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchHistoryRequest.predicate = predicate
        
        if let historyObjects = try? context?.fetch(fetchHistoryRequest) {
            //print("historyObjects \(historyObjects)")
            
            for history in historyObjects {
                context?.delete(history)
            }
            try? context?.save()
        }
        
       
    }
    
    func saveNewListToDB(listName: String) -> List? {
        
        let newList = List(context: context!)
        newList.name = listName
        
        do {
            try context?.save()

            return newList
         
        } catch {
            print("error, \(error.localizedDescription)")
            return nil
        }
        
    }
    
    // MARK: search
    func search(_ searchTerm: String) {
        if searchTerm.isEmpty {
            
            stockCellDatas.value = onedayStockInfo.map({ item in
                StockCellViewModel(stock: item)
            })
        } else {

            stockCellDatas.value = onedayStockInfo.filter({
                $0.stockNo.contains(searchTerm)
            }).map({ item in
                StockCellViewModel(stock: item)
            })
        }
        
    }
    
    func transformForWidget() {
        let encoder = JSONEncoder()
        let stockListForWidget = onedayStockInfo.map { item in
            return CommonStockInfo(stockNo: item.stockNo, current: item.current, shortName: item.shortName, yesterDayPrice: item.yesterDayPrice)
        }
        do {
            let stockListForWidgetEncode = try encoder.encode(stockListForWidget)
            dataForWidget.value = stockListForWidgetEncode
        } catch let error{
            print(error)
        }
    }
}

