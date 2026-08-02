//
//  SceneICloudCoordinatorTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class FakeBackgroundTaskApplication: BackgroundTaskBeginning {
    private(set) var beginCallCount = 0
    private(set) var endedIdentifiers: [UIBackgroundTaskIdentifier] = []
    var identifierToReturn = UIBackgroundTaskIdentifier(rawValue: 42)

    func beginBackgroundTask(withName taskName: String?, expirationHandler handler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        beginCallCount += 1
        return identifierToReturn
    }

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        endedIdentifiers.append(identifier)
    }
}

final class FakeICloudBackupService: ICloudBackupService {
    private(set) var backupCalls: [BackupTriggerReason] = []
    var snapshotAvailable = false
    private(set) var restoreCallCount = 0

    func backupIfNeeded(reason: BackupTriggerReason) async {
        backupCalls.append(reason)
    }
    func manualBackupNow() async throws {}
    func hasSnapshotAvailable() async -> Bool { snapshotAvailable }
    func restoreLatestSnapshot() async throws { restoreCallCount += 1 }
}

final class SceneICloudCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        backupService: FakeICloudBackupService = FakeICloudBackupService(),
        syncPreference: SyncPreference = .iCloud,
        isFirebaseLoggedIn: Bool = false,
        hasLocalData: Bool = false,
        application: FakeBackgroundTaskApplication = FakeBackgroundTaskApplication()
    ) -> SceneICloudCoordinator {
        SceneICloudCoordinator(
            backupService: backupService,
            syncPreferenceProvider: { syncPreference },
            isFirebaseLoggedIn: { isFirebaseLoggedIn },
            hasLocalData: { hasLocalData },
            application: application
        )
    }

    // MARK: - 8.10 distinct trigger reason for foreground vs launch

    func test_triggerBackupIfEnabled_forwardsGivenReason_toBackupService() async {
        let backupService = FakeICloudBackupService()
        let coordinator = makeCoordinator(backupService: backupService)

        await coordinator.triggerBackupIfEnabled(reason: .didEnterForeground)

        XCTAssertEqual(backupService.backupCalls, [.didEnterForeground])
    }

    func test_triggerBackupIfEnabled_appLaunchAndForeground_areDistinctReasons() async {
        let backupService = FakeICloudBackupService()
        let coordinator = makeCoordinator(backupService: backupService)

        await coordinator.triggerBackupIfEnabled(reason: .appLaunch)
        await coordinator.triggerBackupIfEnabled(reason: .didEnterForeground)

        XCTAssertEqual(backupService.backupCalls, [.appLaunch, .didEnterForeground])
        XCTAssertNotEqual(backupService.backupCalls[0], backupService.backupCalls[1])
    }

    func test_triggerBackupIfEnabled_doesNothing_whenSyncPreferenceIsLocal() async {
        let backupService = FakeICloudBackupService()
        let coordinator = makeCoordinator(backupService: backupService, syncPreference: .local)

        await coordinator.triggerBackupIfEnabled(reason: .didEnterBackground)

        XCTAssertTrue(backupService.backupCalls.isEmpty)
    }

    // MARK: - 8.7 background task begin/end pairing (backgroundTaskID synchronization)

    func test_triggerBackupIfEnabled_beginsAndEndsBackgroundTask_aroundBackup() async {
        let application = FakeBackgroundTaskApplication()
        let coordinator = makeCoordinator(application: application)

        await coordinator.triggerBackupIfEnabled(reason: .didEnterBackground)

        XCTAssertEqual(application.beginCallCount, 1)
        XCTAssertEqual(application.endedIdentifiers, [application.identifierToReturn])
    }

    // MARK: - 8.14 restore-offer gating logic

    func test_shouldOfferRestore_true_whenNotLoggedIn_localEmpty_snapshotAvailable() async {
        let backupService = FakeICloudBackupService()
        backupService.snapshotAvailable = true
        let coordinator = makeCoordinator(backupService: backupService, isFirebaseLoggedIn: false, hasLocalData: false)

        let result = await coordinator.shouldOfferRestore()

        XCTAssertTrue(result)
    }

    func test_shouldOfferRestore_false_whenLoggedIntoFirebase() async {
        let backupService = FakeICloudBackupService()
        backupService.snapshotAvailable = true
        let coordinator = makeCoordinator(backupService: backupService, isFirebaseLoggedIn: true, hasLocalData: false)

        let result = await coordinator.shouldOfferRestore()

        XCTAssertFalse(result)
    }

    func test_shouldOfferRestore_false_whenLocalDataAlreadyExists() async {
        let backupService = FakeICloudBackupService()
        backupService.snapshotAvailable = true
        let coordinator = makeCoordinator(backupService: backupService, isFirebaseLoggedIn: false, hasLocalData: true)

        let result = await coordinator.shouldOfferRestore()

        XCTAssertFalse(result)
    }

    func test_shouldOfferRestore_false_whenNoSnapshotAvailable() async {
        let backupService = FakeICloudBackupService()
        backupService.snapshotAvailable = false
        let coordinator = makeCoordinator(backupService: backupService, isFirebaseLoggedIn: false, hasLocalData: false)

        let result = await coordinator.shouldOfferRestore()

        XCTAssertFalse(result)
    }

    func test_restore_delegatesToBackupService() async throws {
        let backupService = FakeICloudBackupService()
        let coordinator = makeCoordinator(backupService: backupService)

        try await coordinator.restore()

        XCTAssertEqual(backupService.restoreCallCount, 1)
    }
}
