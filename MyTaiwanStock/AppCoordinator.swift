//
//  AppCoordinator.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/4/19.
//

import UIKit

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get set }
    //        var parentCoordinator: Coordinator? { get set }
    //        var childCoordinators: [Coordinator] { get set }

    func start()
}

final class AppCoordinator: Coordinator {
    var navigationController: UINavigationController
    //        var parentCoordinator: Coordinator?
    //        var childCoordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        showStockList()
    }

    private func showStockList() {
        let stockListCoordinator = StockListCoordinator(
            navigationController: navigationController)
        //                stockListCoordinator.parentCoordinator = self
        //                childCoordinators.append(stockListCoordinator)
        stockListCoordinator.start()
    }
}
