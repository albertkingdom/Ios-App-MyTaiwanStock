//
//  PendingImportCoordinator.swift
//  MyTaiwanStock
//

import UIKit

/// Offers the screenshots the share extension left behind: when the app is active, nothing else is going
/// on and a batch is waiting, it asks whether to import them now. Only the answer "now" starts the import;
/// nothing is read or written before that.
///
/// The check runs when the app becomes active, when an import ends and when the stock list appears. A check
/// that finds something in the way (an import running, a modal screen) does nothing and is not queued,
/// because one of those triggers comes again.
@MainActor
final class PendingImportCoordinator {
    private let store: PendingImportStore?
    private let isAppActive: () -> Bool
    private let isImportRunning: () -> Bool
    private let hasModal: () -> Bool
    private let askToImport: (_ imageCount: Int, _ answer: @escaping (Bool) -> Void) -> Void
    private let startImport: (PendingImportBatch, PendingImportStore) -> Void

    private var isAsking = false
    private var isStarting = false
    private var declinedSinceActive = false
    private var checkTask: Task<Void, Never>?
    private var needsAnotherCheck = false

    /// `store` is nil when the shared container cannot be reached; then there is never anything to offer.
    init(
        store: PendingImportStore?,
        isAppActive: @escaping () -> Bool,
        isImportRunning: @escaping () -> Bool,
        hasModal: @escaping () -> Bool,
        askToImport: @escaping (_ imageCount: Int, _ answer: @escaping (Bool) -> Void) -> Void,
        startImport: @escaping (PendingImportBatch, PendingImportStore) -> Void
    ) {
        self.store = store
        self.isAppActive = isAppActive
        self.isImportRunning = isImportRunning
        self.hasModal = hasModal
        self.askToImport = askToImport
        self.startImport = startImport
    }

    /// The app became active. The check waits one turn of the run loop so that what the launch shows by
    /// itself, such as the iCloud restore question, comes first.
    func appDidBecomeActive() {
        declinedSinceActive = false
        // A question that is still on screen is found as a modal screen. One that never made it to the
        // screen would otherwise block every later question, because only an answer clears it.
        isAsking = false
        checkSoon()
    }

    /// An import flow ended. The modal screen it used may still be on its way out, so the check waits a turn.
    func importDidFinish() {
        checkSoon()
    }

    private func checkSoon() {
        DispatchQueue.main.async { [weak self] in self?.check() }
    }

    /// Looks for a pending batch and asks about it. The folder is read off the main thread; a trigger that
    /// arrives meanwhile makes the check run once more, because what it found may be out of date.
    func check() {
        guard canAsk else { return }
        guard checkTask == nil else {
            needsAnotherCheck = true
            return
        }
        checkTask = Task { [weak self] in
            await self?.performCheck()
            guard let self else { return }
            checkTask = nil
            if needsAnotherCheck {
                needsAnotherCheck = false
                check()
            }
        }
    }

    /// Waits until no check is running, including the one a trigger during a check asks for.
    func waitForChecks() async {
        while let task = checkTask { await task.value }
    }

    private var canAsk: Bool {
        store != nil && isAppActive() && !isAsking && !isStarting && !declinedSinceActive && !isImportRunning()
    }

    private func performCheck() async {
        guard let store else { return }
        let batch = await Task.detached(priority: .utility) { () -> PendingImportBatch? in
            store.purgeStale()
            return store.batches().first
        }.value
        // The app may have changed while the folder was read.
        guard canAsk, !hasModal(), let batch else { return }

        isAsking = true
        askToImport(batch.imageURLs.count) { [weak self] importNow in
            guard let self else { return }
            isAsking = false
            guard importNow else {
                declinedSinceActive = true
                return
            }
            // Showing the stock list may trigger a check of its own; the import being started must not be offered again.
            isStarting = true
            startImport(batch, store)
            isStarting = false
        }
    }
}

// MARK: - the app's screens

extension PendingImportCoordinator {
    /// A coordinator wired to the stock list tab of the app.
    static func make(
        window: UIWindow,
        tabBarController: UITabBarController,
        stockListCoordinator: StockListCoordinator
    ) -> PendingImportCoordinator {
        PendingImportCoordinator(
            store: PendingImportStore.forAppGroup(),
            isAppActive: { UIApplication.shared.applicationState == .active },
            isImportRunning: { stockListCoordinator.isImportInProgress },
            hasModal: { hasModal(in: window) },
            askToImport: { count, answer in
                window.rootViewController?.present(makePrompt(imageCount: count, answer: answer), animated: true)
            },
            startImport: { batch, store in
                showImport(
                    of: PendingBatchImageSource(batch: batch, store: store),
                    in: tabBarController, navigationController: stockListCoordinator.navigationController)
            })
    }

    /// Shows the stock list at its root, whatever page the user was on, and runs the import there. The root
    /// comes without animation so the loading screen appears over the list at once.
    static func showImport(
        of source: TradeImageSource,
        in tabBarController: UITabBarController,
        navigationController: UINavigationController
    ) {
        tabBarController.selectedIndex = 0   // the first tab is the stock list
        navigationController.popToRootViewController(animated: false)
        guard let list = navigationController.viewControllers.first as? StockListViewController else {
            logger.error("The first tab does not show the stock list, so the pending import cannot start")
            return
        }
        list.startImport(of: source)
    }

    /// Whether any screen is presented over the app, a question or the photo picker included.
    static func hasModal(in window: UIWindow) -> Bool {
        window.rootViewController?.presentedViewController != nil
    }

    static func makePrompt(imageCount: Int, answer: @escaping (Bool) -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "有 \(imageCount) 張待匯入的截圖",
            message: "要現在匯入嗎？",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "稍後", style: .cancel) { _ in answer(false) })
        alert.addAction(UIAlertAction(title: "現在匯入", style: .default) { _ in answer(true) })
        alert.preferredAction = alert.actions.last
        return alert
    }
}
