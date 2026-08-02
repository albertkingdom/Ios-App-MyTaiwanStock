//
//  SceneICloudCoordinator.swift
//  MyTaiwanStock
//

import UIKit
import FirebaseAuth

/// Abstracts `UIApplication`'s background-task API so tests can verify begin/end pairing
/// without a real `UIApplication`.
protocol BackgroundTaskBeginning {
    func beginBackgroundTask(withName taskName: String?, expirationHandler handler: (@Sendable () -> Void)?) -> UIBackgroundTaskIdentifier
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

extension UIApplication: BackgroundTaskBeginning {}

/// Owns the single `UIBackgroundTaskIdentifier` used around an iCloud backup so its
/// read/write is protected from the data race between the `beginBackgroundTask` expiration
/// handler (which can fire on a background thread) and the awaiting `Task` that also
/// clears it on normal completion.
actor BackgroundTaskTracker {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    func begin(using application: BackgroundTaskBeginning, name: String) {
        let id = application.beginBackgroundTask(withName: name) { [weak self] in
            Task { await self?.endIfNeeded(using: application) }
        }
        identifier = id
    }

    func endIfNeeded(using application: BackgroundTaskBeginning) {
        guard identifier != .invalid else { return }
        application.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

/// Extracted from `SceneDelegate` so the iCloud backup-trigger and restore-offer logic is
/// unit-testable in isolation from real `UIApplication`/`Auth`/`LocalDBService` state.
final class SceneICloudCoordinator {
    private let backupService: ICloudBackupService
    private let syncPreferenceProvider: () -> SyncPreference
    private let isFirebaseLoggedIn: () -> Bool
    private let hasLocalData: () -> Bool
    private let application: BackgroundTaskBeginning
    private let backgroundTaskTracker = BackgroundTaskTracker()

    init(
        backupService: ICloudBackupService = DefaultICloudBackupService.shared,
        syncPreferenceProvider: @escaping () -> SyncPreference = { UserPreferences.shared.syncPreference },
        isFirebaseLoggedIn: @escaping () -> Bool = { Auth.auth().currentUser != nil },
        hasLocalData: @escaping () -> Bool = { !LocalDBService.shared.fetchAllListFromDB().isEmpty },
        application: BackgroundTaskBeginning = UIApplication.shared
    ) {
        self.backupService = backupService
        self.syncPreferenceProvider = syncPreferenceProvider
        self.isFirebaseLoggedIn = isFirebaseLoggedIn
        self.hasLocalData = hasLocalData
        self.application = application
    }

    /// Runs the iCloud backup check within a background execution window, gated on the
    /// user's iCloud backup preference. `ICloudBackupService` itself decides whether a
    /// backup is actually due (change detection + throttling).
    func triggerBackupIfEnabled(reason: BackupTriggerReason) async {
        guard syncPreferenceProvider() == .iCloud else { return }

        await backgroundTaskTracker.begin(using: application, name: "ICloudBackup")
        await backupService.backupIfNeeded(reason: reason)
        await backgroundTaskTracker.endIfNeeded(using: application)
    }

    /// Offers to restore from an iCloud backup snapshot only when the user has never
    /// logged into Firebase and the local Core Data store is currently empty. Once a
    /// Firebase login exists, Firestore is the sole authority for restore and this path
    /// SHALL NOT run (see specs/account-login and specs/icloud-backup).
    func shouldOfferRestore() async -> Bool {
        guard !isFirebaseLoggedIn() else { return false }
        guard !hasLocalData() else { return false }
        return await backupService.hasSnapshotAvailable()
    }

    func restore() async throws {
        try await backupService.restoreLatestSnapshot()
    }
}
