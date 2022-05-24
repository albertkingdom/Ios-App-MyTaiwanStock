//
//  AddStockNoViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Combine
import Foundation

class AddStockNoViewModel {

    var filteredAddStockCellViewModelsCombine = CurrentValueSubject<[AddStockCellViewModel], Never>([])
    var followingStockNoList: Set<String> = []
    var searchText = CurrentValueSubject<String, Never>("")
    var subscription = Set<AnyCancellable>()

    
    init() {
        
        setupSearchText()
    }
    

    
    func setupSearchText() {
        searchText
            .removeDuplicates()
            .map { str -> [AddStockCellViewModel] in
                
                return stockNoList
                    .filter({ string in
                        string.contains(str)
                    })
                    .map({ string in
                        AddStockCellViewModel(stockNumberAndName: string, followingStockNoList: self.followingStockNoList)
                    })
            }
            .sink { [weak self] cellData in
                
                self?.filteredAddStockCellViewModelsCombine.send(cellData)
            }
            .store(in: &subscription)

            
    }
}
