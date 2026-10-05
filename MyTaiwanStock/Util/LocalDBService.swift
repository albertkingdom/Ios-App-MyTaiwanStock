//
//  LocalDBService.swift
//  MyTaiwanStock
//
//  Created by YKLin on 10/8/22.
//

import Foundation
import CoreData
import UIKit
import CloudKit


extension Notification.Name {
    static let dataSaveDidFail = Notification.Name("LocalDBService.dataSaveDidFail")
}

class LocalDBService {

    static let appGroupIdentifier = "group.a2006mike.myTaiwanStock"
    static let databaseName = "MyTaiwanStock"

    static let shared = LocalDBService()
    var container: NSPersistentContainer
    private let iCloudAvailabilityChecking: ICloudAvailabilityChecking

    // MARK: - Core Data Saving support

    func saveContext() {
        let context = container.viewContext

        if self.context.hasChanges {
            do {
                try context.save()

            } catch {
                let nserror = error as NSError
                print("LocalDBService.saveContext failed: \(nserror), \(nserror.userInfo)")
                NotificationCenter.default.post(name: .dataSaveDidFail, object: nserror)
            }
        }
    }


    var context: NSManagedObjectContext {
        return self.container.viewContext
    }

    private init(iCloudAvailabilityChecking: ICloudAvailabilityChecking = DefaultICloudAvailabilityChecker()) {
        self.iCloudAvailabilityChecking = iCloudAvailabilityChecking
        container = LocalDBService.configureContainer()
        loadPersistentStores()

        if !iCloudAvailabilityChecking.isICloudAvailable() {
            print("LocalDBService: iCloud is not available on this device; iCloud backup will be disabled but local Core Data continues to work normally.")
        }
    }

    static func configureContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: databaseName)
        guard let storeURL = URL.storeURL(for: appGroupIdentifier, databaseName: databaseName) else {
            fatalError("App group container '\(appGroupIdentifier)' could not be resolved. Check the application-groups entitlement configuration.")
        }
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [storeDescription]
        return container
    }

    func loadPersistentStores() {
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                if let ckErrorCode = Self.knownRecoverableCKErrorCode(for: error) {
                    print("LocalDBService.loadPersistentStores: known CloudKit-related error \(ckErrorCode) — \(error.localizedDescription). Continuing without interrupting initialization.")
                } else {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // `loadPersistentStores` can run more than once (e.g. `reloadPersistentStore()`
        // after an iCloud restore) — remove any prior registration first so the observer
        // is never registered twice for the same coordinator.
        NotificationCenter.default.removeObserver(self, name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChangeNotification),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    /// Removes the currently loaded persistent store(s) and reloads from disk. Must be
    /// called after an iCloud restore replaces the underlying SQLite file out from under
    /// an already-running `NSPersistentContainer` — otherwise the in-memory connection
    /// keeps pointing at the old, now-replaced file handle, and the next write can corrupt
    /// the freshly restored file.
    func reloadPersistentStore() throws {
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
        loadPersistentStores()
        // 還原進來的舊備份可能含重複資料。還原在 actor 上執行，要切到 viewContext 的 queue
        container.viewContext.performAndWait {
            removeDuplicateListsAndStockNos()
        }
    }

    /// CKError codes that are known, recoverable conditions and must not crash initialization.
    static let knownRecoverableCKErrorCodes: Set<CKError.Code> = [
        .notAuthenticated,
        .networkUnavailable,
        .serverRecordChanged,
        .zoneNotFound,
        .partialFailure,
        .quotaExceeded,
    ]

    /// Returns the matching `CKError.Code` when `error` is a known, recoverable CloudKit
    /// error (domain `CKErrorDomain` and a code in `knownRecoverableCKErrorCodes`), else `nil`.
    /// Extracted as a pure function so the classification logic is unit-testable without
    /// triggering real store loading or `fatalError`.
    static func knownRecoverableCKErrorCode(for error: NSError) -> CKError.Code? {
        guard error.domain == CKError.errorDomain else { return nil }
        guard let code = CKError.Code(rawValue: error.code) else { return nil }
        return knownRecoverableCKErrorCodes.contains(code) ? code : nil
    }

    @objc private func handleRemoteChangeNotification(_ notification: Notification) {
        // Handle the notification to update your UI or state
        print("Data from iCloud has been synced.")
    }
//    private func createCoreDataContentChangeObserver() {
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleStoreChange(_:)),
//            name: .NSManagedObjectContextObjectsDidChange,
//            object: persistentContainer.persistentStoreCoordinator
//        )
//    }

//    @objc private func handleStoreChange(_ notification: Notification?) {
//        print("handleStoreChange")
//        if let notification = notification {
//            print("Core Data數據發生變化: \(notification)")
//            timer?.invalidate()
//        } else {
//            print("超時，Core Data沒有數據變化")
//        }
//        NotificationCenter.default.post(name: .coreDataDidUpdate, object: nil)
//    }
    // MARK: Core Data - fetch list
    func fetchAllListFromDB() -> [ListStruct]{
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        do {
            let result = try context.fetch(fetchRequest)
            let listStructs = result.compactMap { $0.toStruct() }
            return listStructs
        } catch let error {
            print(error.localizedDescription)
            return []
        }
    }
    
    // MARK: Core Data - fetch history
    func fetchHistoryFromDB(with stockNo: String) -> [InvestHistory]{
        
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo == %@", stockNo)
        var lists: [InvestHistory] = []
        do {
            let result = try context.fetch(fetchRequest)
            lists = result
            
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    
    /// The date of every buy/sell record, across all stocks.
    func fetchAllHistoryDates() -> [Date] {
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        do {
            return try context.fetch(fetchRequest).compactMap(\.date)
        } catch let error {
            print(error.localizedDescription)
            return []
        }
    }

    // MARK: fetch stock dividend
    func fetchAllStockDividend() -> [StockDividend] {
        
        let fetchRequest: NSFetchRequest<StockDividend> = StockDividend.fetchRequest()
        
        var lists: [StockDividend] = []
        do {
            let result = try context.fetch(fetchRequest)
            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    func fetchAllStockDividend(with stockNo: String) -> [StockDividend] {
        
        let fetchRequest: NSFetchRequest<StockDividend> = StockDividend.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo == %@", stockNo)
        
        var lists: [StockDividend] = []
        do {
            let result = try context.fetch(fetchRequest)
            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    // MARK: fetch cash dividend
    func fetchAllCashDividend() -> [CashDividend] {
        
        let fetchRequest: NSFetchRequest<CashDividend> = CashDividend.fetchRequest()
        
        var lists: [CashDividend] = []
        do {
            let result = try context.fetch(fetchRequest)
            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    func fetchAllCashDividend(with stockNo: String) -> [CashDividend] {
        
        let fetchRequest: NSFetchRequest<CashDividend> = CashDividend.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo == %@", stockNo)
        
        var lists: [CashDividend] = []
        do {
            let result = try context.fetch(fetchRequest)
            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    // update currentPrice property of stockNo
    func updateStockNoInDBwithPrice(stockNos: [String], cellViewModels: [StockCellViewModel]) {
        
        let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo IN %@", stockNos)
        do {
            let stocks = try context.fetch(fetchRequest)
            print("updateStockNoFromDBwithPrice stocks \(stocks), stocks count \(stocks.count)")
            
            for stock in stocks {
                if let price = cellViewModels.first(where: {$0.stockNo==stock.stockNo})?.stockPrice,
                   let priceDouble = Double(price) {
                    
                    stock.currentPrice = priceDouble
                }
                
            }
            saveContext()
            
        } catch let error {
            print(error.localizedDescription)
        }
        
    }
    
    func fetchStockPriceFromDB(with stockNos: [String]) -> [StockNo]{
        let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stockNo IN %@", stockNos)
        do {
            let stocks = try context.fetch(fetchRequest)
            print("fetchStockPriceFromDB stocks \(stocks), stocks count \(stocks.count)")
            
            return stocks
            
        } catch let error {
            print(error.localizedDescription)
        }
        return []
    }
    // MARK: Core Data - save list
    func saveNewListToDB(listName: String) -> List? {
        // 同名清單已存在就直接回傳，避免建立重複清單
        if let existingList = fetchListMO(withName: listName) {
            return existingList
        }

        let newList = List(context: context)
        newList.name = listName
        
        saveContext()
        return newList
    }
    // MARK: Core Data - save stockNo
    func saveNewStockNumberToDB(stockNumber: String, currentFollowingList: ListStruct) {
        
        if let listMO = fetchListMO(withName: currentFollowingList.name) {
                // 1. 已在清單中就不重複寫入
                let existingStockNos = (listMO.stockNo as? Set<NSManagedObject> ?? [])
                    .compactMap { $0.value(forKey: "stockNo") as? String }
                if existingStockNos.contains(stockNumber) { return }

                // 2. 創建新的 StockNo Core Data 物件
                let newStockNoMO = StockNo(context: context)
                newStockNoMO.stockNo = stockNumber

                // 3. 建立 StockNo 和 List 之間的關聯
                newStockNoMO.ofList = listMO

                // 4. 將新的 StockNo 添加到 List 的 stockNo 關聯中 (確保關係設定正確)
                if var stockNoSet = listMO.stockNo as? NSMutableSet {
                    stockNoSet.add(newStockNoMO)
                    listMO.stockNo = stockNoSet as NSSet
                } else {
                    listMO.stockNo = NSSet(object: newStockNoMO)
                }

                // 5. 保存 Core Data 上下文
                saveContext()
            } else {
                print("錯誤：找不到名為 '\(currentFollowingList.name ?? "")' 的 List 物件，無法添加新的股票代號。")
            }
    }
    private func fetchListMO(withName name: String?) -> List? {
        guard let listName = name else { return nil }
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", listName)

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("提取名為 '\(listName)' 的 List 失敗：\(error)")
            return nil
        }
    }
    
    // MARK: Core Data - save new record
    func saveNewRecord(
        stockNo: String,
        price: Float,
        amount: Int,
        reason: String,
        buyOrSellStatus: Int,
        date: Date
    ) {
        
        let newInvestHistory = InvestHistory(context: context)
        newInvestHistory.stockNo = stockNo
        newInvestHistory.price = price
        newInvestHistory.amount = Int16(amount)
        newInvestHistory.date = date
        newInvestHistory.status = Int16(buyOrSellStatus)
        newInvestHistory.reason = reason
        saveContext()
        
    }
    // MARK: Core Data - save new stock dividend record
    func saveStockDividend(stockNo: String, amount: Int, date: Date) {
        let new = StockDividend(context: context)
        new.stockNo = stockNo
        new.amount = Int16(amount)
        new.date = date
        
        saveContext()
    }
    
    // MARK: Core Data - save new cash dividend record
    func saveCashDividend(stockNo: String, amount: Int, date: Date) {
        let new = CashDividend(context: context)
        new.stockNo = stockNo
        new.amount = Int16(amount)
        new.date = date
        
        saveContext()
    }
    
    // MARK: Core Data - delete
    func deleteStockNumberInDB(stockNoObject: StockNoStruct, listName: String) {
//        context.delete(stockNoObject)
//        
//        let result = checkIfRemainingStockNoObject(with: stockNoObject.stockNo!)
//        
//        if !result {
//            deleteHistory(with: stockNoObject.stockNo!)
//        }
//        // TODO: show the UIAlert
//        saveContext()
        StockNo.delete(with: stockNoObject, listName: listName, in: context)
        
    }
    // MARK: Core Data - remove duplicates
    /// 清理舊版本留下的重複資料：合併同名清單、移除清單內重複的 stockNo
    func removeDuplicateListsAndStockNos() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "List")
        guard let lists = try? context.fetch(request) else { return }

        var keptListsByName: [String: NSManagedObject] = [:]
        for list in lists {
            guard let name = list.value(forKey: "name") as? String else { continue }
            guard let keptList = keptListsByName[name] else {
                keptListsByName[name] = list
                continue
            }
            // 同名清單：把股票移到保留的清單後刪除
            let stockNoObjects = list.value(forKey: "stockNo") as? Set<NSManagedObject> ?? []
            for stockNoObject in stockNoObjects {
                stockNoObject.setValue(keptList, forKey: "ofList")
            }
            context.delete(list)
        }

        for list in keptListsByName.values {
            var seenStockNos = Set<String>()
            let stockNoObjects = list.value(forKey: "stockNo") as? Set<NSManagedObject> ?? []
            for stockNoObject in stockNoObjects {
                guard let stockNo = stockNoObject.value(forKey: "stockNo") as? String else { continue }
                if !seenStockNos.insert(stockNo).inserted {
                    context.delete(stockNoObject)
                }
            }
        }

        saveContext()
    }

    func deleteHistoryInDB(historyObject: InvestHistory) {
        context.delete(historyObject)
        saveContext()
    }
    private func checkIfRemainingStockNoObject(with stockNo: String) -> Bool {
        let fetchStockRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchStockRequest.predicate = predicate
        
        if let stockNoObjects = try? context.fetch(fetchStockRequest) {
            
            if stockNoObjects.isEmpty {
                // there's no stockNo object with same stockNo
                return false
            }
        }
        return true
    }
    private func deleteHistory(with stockNo: String) {
        // fetch history with stockNo, then delete them
        let fetchHistoryRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let predicate = NSPredicate(format: "stockNo == %@", stockNo)
        fetchHistoryRequest.predicate = predicate
        
        if let historyObjects = try? context.fetch(fetchHistoryRequest) {
            
            for history in historyObjects {
                context.delete(history)
            }
            saveContext()
        }
    }
    func deleteListFromDB(list: ListStruct) {
//        context.delete(list)
//        saveContext()
        List.delete(with: list, in: context)
    }
    
    /// 回傳是否有改名，讓呼叫端決定要不要同步到 Firestore
    @discardableResult
    func updateListName(newName: String, oldName: String) -> Bool {
        // 新名稱已被其他清單使用就不改，避免產生同名清單
        guard newName == oldName || fetchListMO(withName: newName) == nil else { return false }
        let updatedListInfo = ListStruct(name: newName, stockNos: []) // stockNos 在這裡通常不需要

        List.updateName(with: updatedListInfo, in: context, currentName: oldName)
        return true
    }
    
}

