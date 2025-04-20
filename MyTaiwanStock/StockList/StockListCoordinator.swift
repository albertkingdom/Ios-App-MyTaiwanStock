//
//  StockListCoordinator.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/4/19.
//

import UIKit

protocol StockListCoordinatorProtocol: AnyObject {
    func showStockDetail(
        stockNo: String, currentStockPrice: String, stockName: String,
        stockPriceDiff: String, timeString: String)
    func showAddList()
    func showAddStock(
        followingStockNoList: Set<String>, listName: String,
        addNewStockToDB: @escaping (String) -> Void)
}

final class StockListCoordinator: Coordinator {
    var navigationController: UINavigationController
    var parentCoordinator: Coordinator?
    var childCoordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard
            let viewController = storyboard.instantiateViewController(
                withIdentifier: "stockListVC") as? StockListViewController
        else {
            fatalError("Could not find StockListViewController in storyboard")
        }

        // Create ViewModel with coordinator
        let viewModel = StockListViewModel(
            repository: DependencyContainer.shared.networkService,
            coordinator: self)

        // Configure ViewController with ViewModel
        viewController.configure(with: viewModel)

        navigationController.setViewControllers(
            [viewController], animated: false)
    }
}

extension StockListCoordinator: StockListCoordinatorProtocol {
    func showStockDetail(
        stockNo: String, currentStockPrice: String, stockName: String,
        stockPriceDiff: String, timeString: String
    ) {
        let stockViewController = DependencyContainer.shared
            .configureStockDetailViewController(
                stockNo: stockNo,
                currentStockPrice: currentStockPrice
            )
        stockViewController.stockPrice = currentStockPrice
        stockViewController.stockName = stockName
        stockViewController.stockPriceDiff = stockPriceDiff
        stockViewController.timeString = timeString
        navigationController.pushViewController(
            stockViewController, animated: true)
    }

    func showAddList() {
   
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let addListVC = storyboard.instantiateViewController(identifier: "addListVC") as? AddListViewController else {
            fatalError("Unable to instantiate AddListViewController from storyboard")
        }

        navigationController.pushViewController(addListVC, animated: true)
    }

    func showAddStock(
        followingStockNoList: Set<String>, listName: String,
        addNewStockToDB: @escaping (String) -> Void
    ) {
//
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let addStockViewController = storyboard.instantiateViewController(identifier: "addStockVC") as? AddStockNoViewController else {
            fatalError("Unable to instantiate addStockVC from storyboard")
        }
        addStockViewController.followingStockNoList = followingStockNoList
        addStockViewController.addNewStockToDB = addNewStockToDB
        addStockViewController.listName = listName
        navigationController.pushViewController(
            addStockViewController, animated: false)
    }
}
