//
//  List+CoreDataProperties.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/4/26.
//
//

import Foundation
import CoreData


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

extension List : Identifiable {

}
