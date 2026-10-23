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
    /// Starts the screenshot import: pick screenshots, review the recognized trades, import.
    /// `onImported` runs after trades were written, so the home screen can reload.
    func showImportTrades(
        listNames: [String], currentListName: String?,
        onImported: @escaping () -> Void)
    /// Runs the import on screenshots that are already at hand, such as a pending batch from the share
    /// extension, instead of asking the user to pick them.
    func showImportTrades(
        of source: TradeImageSource, listNames: [String], currentListName: String?,
        onImported: @escaping () -> Void)
    /// Whether an import flow is running, from picking the screenshots to closing the preview.
    var isImportInProgress: Bool { get }
}

final class StockListCoordinator: Coordinator {
    var navigationController: UINavigationController
    var parentCoordinator: Coordinator?
    var childCoordinators: [Coordinator] = []
    private var importFlow: TradeImportFlow?
    /// Runs when an import ends, however it ends, so the pending batches are looked at again. An
    /// interrupted import kept its batch, which is offered again once the app is active.
    var onImportFinished: (() -> Void)?

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
    var isImportInProgress: Bool {
        MainActor.assumeIsolated { importFlow?.state == .inProgress }
    }

    func showImportTrades(
        listNames: [String], currentListName: String?,
        onImported: @escaping () -> Void
    ) {
        // Called from a button tap, so already on the main thread.
        MainActor.assumeIsolated {
            makeImportFlow(listNames: listNames, currentListName: currentListName, onImported: onImported)?.start()
        }
    }

    func showImportTrades(
        of source: TradeImageSource, listNames: [String], currentListName: String?,
        onImported: @escaping () -> Void
    ) {
        MainActor.assumeIsolated {
            makeImportFlow(listNames: listNames, currentListName: currentListName, onImported: onImported)?
                .start(importing: source)
        }
    }

    /// Nil while another import is still running, so a second one never starts on top of it.
    @MainActor
    private func makeImportFlow(
        listNames: [String], currentListName: String?, onImported: @escaping () -> Void
    ) -> TradeImportFlow? {
        guard !isImportInProgress else { return nil }
        let flow = TradeImportFlow(
            navigationController: navigationController,
            listNames: listNames,
            currentListName: currentListName,
            onImported: onImported,
            onFinished: { [weak self] _ in
                self?.importFlow = nil
                self?.onImportFinished?()
            })
        importFlow = flow  // the flow is its own picker's delegate, so something must keep it alive
        return flow
    }

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
