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
