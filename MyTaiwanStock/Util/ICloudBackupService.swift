//
//  ICloudBackupService.swift
//  MyTaiwanStock
//

import Foundation

enum BackupTriggerReason {
    case didEnterBackground
    case appLaunch
    case didEnterForeground
    case manual
}

enum ICloudBackupServiceError: Error {
    /// iCloud is unavailable (no ubiquity identity token) at the time restore was attempted.
    case iCloudUnavailable
    /// The snapshot's Core Data model version is incompatible with the currently-running
    /// model. Restore is aborted without touching the local store.
    case incompatibleSnapshotSchema
}

protocol ICloudBackupService {
    func backupIfNeeded(reason: BackupTriggerReason) async
    func restoreLatestSnapshot() async throws
    func manualBackupNow() async throws
    // `async` (not sync) so an `actor` conformer's isolated implementation doesn't
    // trigger "conformance crosses into actor-isolated code" — a synchronous
    // actor-isolated method can satisfy an `async` protocol requirement transparently.
    func hasSnapshotAvailable() async -> Bool
}

/// An `actor` so `backupIfNeeded`/`manualBackupNow`/`restoreLatestSnapshot` are naturally
/// serialized: overlapping calls (e.g. the user double-tapping "立即備份", or a manual
/// backup racing the background auto-backup) queue up on the actor instead of racing on
/// the same snapshot/store files.
actor DefaultICloudBackupService: ICloudBackupService {
    static let throttleInterval: TimeInterval = 3600
    private static let lastBackupDateKey = "ICloudBackupService.lastBackupDate"

    private let clock: BackupClock
    private let availabilityChecking: ICloudAvailabilityChecking
    private let destination: BackupDestination
    private let schemaCompatibilityChecking: StoreSchemaCompatibilityChecking
    private let sourceStoreURL: () -> URL?
    private let reloadStore: () throws -> Void
    private let userDefaults: UserDefaults

    init(
        clock: BackupClock = SystemBackupClock(),
        availabilityChecking: ICloudAvailabilityChecking = DefaultICloudAvailabilityChecker(),
        destination: BackupDestination,
        schemaCompatibilityChecking: StoreSchemaCompatibilityChecking,
        sourceStoreURL: @escaping () -> URL?,
        reloadStore: @escaping () throws -> Void,
        userDefaults: UserDefaults = .standard
    ) {
        self.clock = clock
        self.availabilityChecking = availabilityChecking
        self.destination = destination
        self.schemaCompatibilityChecking = schemaCompatibilityChecking
        self.sourceStoreURL = sourceStoreURL
        self.reloadStore = reloadStore
        self.userDefaults = userDefaults
    }

    private var lastBackupDate: Date? {
        get { userDefaults.object(forKey: Self.lastBackupDateKey) as? Date }
        set { userDefaults.set(newValue, forKey: Self.lastBackupDateKey) }
    }

    func backupIfNeeded(reason: BackupTriggerReason) async {
        guard availabilityChecking.isICloudAvailable() else {
            print("ICloudBackupService: iCloud unavailable, skip backup (reason: \(reason))")
            return
        }
        guard let storeURL = sourceStoreURL(), FileManager.default.fileExists(atPath: storeURL.path) else {
            return
        }

        if reason != .manual {
            guard shouldBackup(storeURL: storeURL) else { return }
        }

        do {
            try destination.write(snapshotAt: storeURL)
            lastBackupDate = clock.now()
        } catch {
            print("ICloudBackupService: backup failed: \(error)")
        }
    }

    func manualBackupNow() async throws {
        guard availabilityChecking.isICloudAvailable() else {
            throw ICloudBackupServiceError.iCloudUnavailable
        }
        guard let storeURL = sourceStoreURL(), FileManager.default.fileExists(atPath: storeURL.path) else { return }
        try destination.write(snapshotAt: storeURL)
        lastBackupDate = clock.now()
    }

    func hasSnapshotAvailable() -> Bool {
        destination.latestSnapshotURL() != nil
    }

    func restoreLatestSnapshot() async throws {
        guard availabilityChecking.isICloudAvailable() else {
            throw ICloudBackupServiceError.iCloudUnavailable
        }
        guard let snapshotURL = destination.latestSnapshotURL(),
              let storeURL = sourceStoreURL()
        else {
            throw BackupDestinationError.ubiquityContainerUnavailable
        }
        guard schemaCompatibilityChecking.isCompatible(storeAt: snapshotURL) else {
            throw ICloudBackupServiceError.incompatibleSnapshotSchema
        }

        let sourceSet = SQLiteStoreFileSet(mainURL: snapshotURL)
        let destinationSet = SQLiteStoreFileSet(mainURL: storeURL)
        for (source, destinationURL) in zip(sourceSet.allURLs, destinationSet.allURLs) {
            try CoordinatedFileReplace.replace(destination: destinationURL, withContentsOf: source)
        }

        // The running `NSPersistentContainer` still holds a connection to the file we just
        // replaced out from under it — reload so it picks up the restored content instead
        // of writing the next change into a stale handle.
        try reloadStore()
    }

    /// A backup is due when data changed since the last backup (store file modified
    /// after the last backup timestamp) and the throttle window has elapsed.
    private func shouldBackup(storeURL: URL) -> Bool {
        guard let lastBackupDate else { return true }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
              let modificationDate = attributes[.modificationDate] as? Date
        else {
            return true
        }

        let hasChanged = modificationDate > lastBackupDate
        let throttleElapsed = clock.now().timeIntervalSince(lastBackupDate) >= Self.throttleInterval
        return hasChanged && throttleElapsed
    }
}

extension DefaultICloudBackupService {
    static let shared = DefaultICloudBackupService(
        destination: ICloudDriveBackupDestination(
            ubiquityContainerIdentifier: "iCloud.com.a2006mike.MyTaiwanStock2",
            snapshotFileName: "MyTaiwanStock-backup.sqlite"
        ),
        schemaCompatibilityChecking: CoreDataSchemaCompatibilityChecker(
            managedObjectModel: { LocalDBService.shared.container.managedObjectModel }
        ),
        sourceStoreURL: {
            URL.storeURL(for: LocalDBService.appGroupIdentifier, databaseName: LocalDBService.databaseName)
        },
        reloadStore: {
            try LocalDBService.shared.reloadPersistentStore()
        }
    )
}
