//
//  AddStockViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//

import Foundation

struct AddStockCellViewModel {
    let stockNumberAndName: String
    var stockNumberString: String {
        return String(stockNumberAndName.split(separator: " ")[0])
    }
    let followingStockNoList: Set<String>
    var isFollowing: Bool {
        return followingStockNoList.contains(stockNumberString)
    }
    
    init(stockNumberAndName: String, followingStockNoList: Set<String>) {
        self.stockNumberAndName = stockNumberAndName
        self.followingStockNoList = followingStockNoList
    }
}
