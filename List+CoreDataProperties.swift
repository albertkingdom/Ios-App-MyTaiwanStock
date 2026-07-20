//
//  List+CoreDataProperties.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/4/26.
//
//

import CoreData
import Foundation

extension List {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<List> {
        return NSFetchRequest<List>(entityName: "List")
    }

    @NSManaged public var name: String?
    @NSManaged public var stockNo: NSSet?

}

// MARK: Generated accessors for stockNo
extension List {

    @objc(addStockNoObject:)
    @NSManaged public func addToStockNo(_ value: StockNo)

    @objc(removeStockNoObject:)
    @NSManaged public func removeFromStockNo(_ value: StockNo)

    @objc(addStockNo:)
    @NSManaged public func addToStockNo(_ values: NSSet)

    @objc(removeStockNo:)
    @NSManaged public func removeFromStockNo(_ values: NSSet)

}

extension List: Identifiable {

}

extension List {
    // 將 List (NSManagedObject) 轉換為 ListStruct
    func toStruct() -> ListStruct? {
        guard let name = self.name else {
            return nil
        }

        // 將 stockNo NSSet 轉換為包含 StockNoStruct 的陣列
        let stockNos = self.stockNo as? Set<StockNo> ?? []
        let stockNoStructs = stockNos.map { $0.toStruct() }

        return ListStruct(name: name, stockNos: Array(stockNoStructs))
    }

    // 從 ListStruct 創建或更新 List (NSManagedObject)
    static func fromStruct(
        _ listStruct: ListStruct, in context: NSManagedObjectContext
    ) -> List {
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name == %@", listStruct.name ?? "")

        do {
            let results = try context.fetch(fetchRequest)
            if let existingList = results.first {
                existingList.name = listStruct.name
                // 注意：更新關聯需要更複雜的邏輯
                return existingList
            } else {
                let newList = List(context: context)
                newList.name = listStruct.name
                // 注意：創建新的 List 時，需要根據 stockNos 創建或找到對應的 StockNo 物件並建立關聯
                return newList
            }
        } catch {
            fatalError("Failed to fetch or create List: \(error)")
        }
    }

    // 一個更簡單的創建新 List 物件的方法
    static func create(
        from listStruct: ListStruct, in context: NSManagedObjectContext
    ) -> List {
        let newList = List(context: context)
        newList.name = listStruct.name

        // 處理 stockNo 關聯
        let stockNoSet = listStruct.stockNos.map { stockNoStruct in
            return StockNo.fromStruct(stockNoStruct, in: context)
        }
        newList.stockNo = NSSet(array: stockNoSet)

        return newList
    }
    static func delete(with listStruct: ListStruct, in context: NSManagedObjectContext) {
            guard let listName = listStruct.name else {
                print("錯誤：ListStruct 的 name 為空，無法刪除。")
                return
            }

            let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", listName) // 假設 name 是唯一的

            do {
                let results = try context.fetch(fetchRequest)
                if let listToDelete = results.first {
                    // 從上下文中刪除找到的 List 物件
                    context.delete(listToDelete)

                    // 保存上下文的變更
                    do {
                        try context.save()
                    } catch {
                        print("保存 context 失敗：\(error)")
                    }
                    print("已成功刪除名為 '\(listName)' 的 List。")

                } else {
                    print("警告：找不到名為 '\(listName)' 的 List 物件，無法刪除。")
                }
            } catch {
                print("提取 List 失敗：\(error)")
            }
        }
    
    static func updateName(with updatedListStruct: ListStruct, in context: NSManagedObjectContext, currentName: String) {
            guard let newName = updatedListStruct.name else {
                print("錯誤：updatedListStruct 的 name 為空，無法更新。")
                return
            }

            let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", currentName) // 使用當前的 name 查找

            do {
                let results = try context.fetch(fetchRequest)
                if let existingList = results.first {
                    // 更新 List 的 name 屬性
                    existingList.name = newName

                    // 保存上下文的變更
                    do {
                        try context.save()
                    } catch {
                        print("保存 context 失敗：\(error)")
                    }
                    print("已成功將名為 '\(currentName)' 的 List 更新為 '\(newName)'。")

                } else {
                    print("警告：找不到名為 '\(currentName)' 的 List 物件，無法更新。")
                }
            } catch {
                print("提取 List 失敗：\(error)")
            }
        }
}
