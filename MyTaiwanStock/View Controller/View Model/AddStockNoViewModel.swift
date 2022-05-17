//
//  AddStockNoViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//

import Foundation

class AddStockNoViewModel {

    var filteredAddStockCellViewModels = Observable<[AddStockCellViewModel]>([])
    var followingStockNoList: Set<String> = []
    
    func searchStockNos(with searchTerm: String) {
        self.filteredAddStockCellViewModels.value =
        stockNoList
            .filter({ string in
                string.contains(searchTerm)
            })
            .map({ string in
                AddStockCellViewModel(stockNumberAndName: string, followingStockNoList: followingStockNoList)
            })
    }
}
