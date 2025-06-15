//
//  StockNo+CoreDataProperties.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/4/26.
//
//

import Foundation
import CoreData


extension StockNo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StockNo> {
        return NSFetchRequest<StockNo>(entityName: "StockNo")
    }

    @NSManaged public var currentPrice: Double
    @NSManaged public var stockNo: String?
    @NSManaged public var ofList: List?

}

extension StockNo : Identifiable {

}

extension StockNo {
    func toStruct() -> StockNoStruct {
            return StockNoStruct(currentPrice: self.currentPrice, stockNo: self.stockNo)
        }

        // 從 StockNoStruct 創建或更新 StockNo (NSManagedObject)
        static func fromStruct(_ stockNoStruct: StockNoStruct, in context: NSManagedObjectContext) -> StockNo {
            let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "stockNo == %@", stockNoStruct.stockNo ?? "")

            do {
                let results = try context.fetch(fetchRequest)
                if let existingStockNo = results.first {
                    existingStockNo.currentPrice = stockNoStruct.currentPrice
                    return existingStockNo
                } else {
                    let newStockNo = StockNo(context: context)
                    newStockNo.currentPrice = stockNoStruct.currentPrice
                    newStockNo.stockNo = stockNoStruct.stockNo
                    return newStockNo
                }
            } catch {
                fatalError("Failed to fetch or create StockNo: \(error)")
            }
        }

        // 一個更簡單的創建新 StockNo 物件的方法
        static func create(from stockNoStruct: StockNoStruct, in context: NSManagedObjectContext) -> StockNo {
            let newStockNo = StockNo(context: context)
            newStockNo.currentPrice = stockNoStruct.currentPrice
            newStockNo.stockNo = stockNoStruct.stockNo
            return newStockNo
        }
    
    static func delete(with stockNoStruct: StockNoStruct, in context: NSManagedObjectContext) {
            guard let stockNoToDelete = stockNoStruct.stockNo else {
                print("錯誤：StockNoStruct 的 stockNo 為空，無法刪除。")
                return
            }

            let fetchRequest: NSFetchRequest<StockNo> = StockNo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "stockNo == %@", stockNoToDelete) // 假設 stockNo 是唯一的

            do {
                let results = try context.fetch(fetchRequest)
                if let stockNoToDeleteMO = results.first {
                    // 從上下文中刪除找到的 StockNo 物件
                    context.delete(stockNoToDeleteMO)

                    // 保存上下文的變更
                    do {
                        try context.save()
                    } catch {
                        print("保存 context 失敗：\(error)")
                    }
                    print("已成功刪除 stockNo 為 '\(stockNoToDelete)' 的 StockNo。")

                } else {
                    print("警告：找不到 stockNo 為 '\(stockNoToDelete)' 的 StockNo 物件，無法刪除。")
                }
            } catch {
                print("提取 StockNo 失敗：\(error)")
            }
        }
}
