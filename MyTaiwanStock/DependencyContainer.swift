//
//  DependencyContainer.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/10/31.
//

import Foundation
import UIKit
import CoreData

class DependencyContainer {
    static let shared = DependencyContainer()
    
    lazy var networkService: any NetworkService = {
        return NetworkServiceImpl()
    }()
    
    
    func configureStockListViewController() -> StockListViewController{
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let viewController = storyboard.instantiateViewController(withIdentifier: "stockListVC") as? StockListViewController else {
            fatalError("Could not find UserViewController in storyboard")
        }
        let viewModel = StockListViewModel(repository: networkService)
        viewController.configure(with: viewModel)
        return viewController
    }
    
    func configureStockDetailViewController(
        stockNo: String,
        currentStockPrice: String
    ) -> StockViewController {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let viewController = storyboard.instantiateViewController(withIdentifier: "stockViewController") as? StockViewController else {
            fatalError("Could not find UserViewController in storyboard")
        }
        
        let viewModel = StockDetailViewModel(stockNo: stockNo,
                                             currentStockPrice: currentStockPrice,
                                             repository: networkService)
        viewController.configure(with: viewModel)
        return viewController
    }
    private init() {}
}
