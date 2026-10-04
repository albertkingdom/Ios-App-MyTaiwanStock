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
                
                // The search text is always sent from the main thread (UI input).
                let stockStrings = MainActor.assumeIsolated { StockListRepository.shared.searchStrings }
                return stockStrings
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
