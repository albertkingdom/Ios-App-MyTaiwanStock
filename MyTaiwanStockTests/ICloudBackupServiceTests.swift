//
//  ICloudBackupServiceTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class FakeBackupClock: BackupClock {
    var fixedNow: Date
    init(fixedNow: Date) {
        self.fixedNow = fixedNow
    }
    func now() -> Date {
        fixedNow
    }
}

final class FakeICloudAvailabilityChecker: ICloudAvailabilityChecking {
    var available: Bool
    init(available: Bool) {
        self.available = available
    }
    func isICloudAvailable() -> Bool {
        available
    }
}

final class FakeBackupDestination: BackupDestination {
    private(set) var writeCallCount = 0
    private(set) var lastWrittenURL: URL?
    var snapshotURL: URL?

    func write(snapshotAt url: URL) throws {
        writeCallCount += 1
        lastWrittenURL = url
    }

    func latestSnapshotURL() -> URL? {
        snapshotURL
    }
}

final class FakeStoreSchemaCompatibilityChecker: StoreSchemaCompatibilityChecking {
    var compatible: Bool
    init(compatible: Bool = true) {
        self.compatible = compatible
    }
    func isCompatible(storeAt url: URL) -> Bool {
        compatible
    }
}

/// Records the file it was asked to open; fails when told to. `onVerify` runs first, so a test can change
/// the snapshot while it is being verified.
final class FakeStoreMigrationVerifier: StoreMigrationVerifying {
    struct Failure: Error {}
    var shouldFail = false
    var onVerify: (URL) -> Void = { _ in }
    private(set) var verifiedURLs: [URL] = []

    func verifyStoreCanBeOpened(at url: URL) throws {
        verifiedURLs.append(url)
        onVerify(url)
        if shouldFail { throw Failure() }
    }
}

final class ICloudBackupServiceTests: XCTestCase {
    private var tempStoreURL: URL!
    private var stagingDirectory: URL!

    override func setUp() {
        super.setUp()
        tempStoreURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICloudBackupServiceTests-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: tempStoreURL.path, contents: Data("test".utf8))
        stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICloudBackupServiceTests-staging-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempStoreURL)
        try? FileManager.default.removeItem(at: stagingDirectory)
        tempStoreURL = nil
        stagingDirectory = nil
        super.tearDown()
    }

    private func setStoreModificationDate(_ date: Date) {
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: tempStoreURL.path)
    }

    private func makeService(
        clock: BackupClock,
        available: Bool = true,
        destination: FakeBackupDestination,
        schemaCompatibilityChecking: StoreSchemaCompatibilityChecking = FakeStoreSchemaCompatibilityChecker(),
        migrationVerifier: StoreMigrationVerifying = FakeStoreMigrationVerifier(),
        fileCoordinator: FileCoordinating = NSFileCoordinator(),
        reloadStoreCallCount: ReloadStoreCallCounter = ReloadStoreCallCounter(),
        userDefaults: UserDefaults
    ) -> DefaultICloudBackupService {
        DefaultICloudBackupService(
            clock: clock,
            availabilityChecking: FakeICloudAvailabilityChecker(available: available),
            destination: destination,
            schemaCompatibilityChecking: schemaCompatibilityChecking,
            migrationVerifier: migrationVerifier,
            fileCoordinator: fileCoordinator,
            stagingDirectory: stagingDirectory,
            sourceStoreURL: { self.tempStoreURL },
            reloadStore: { reloadStoreCallCount.increment() },
            userDefaults: userDefaults
        )
    }

    /// Plain reference type so the `reloadStore` closure can record calls without the
    /// service needing to be aware this is a test double.
    final class ReloadStoreCallCounter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    private func freshUserDefaults() -> UserDefaults {
        let suiteName = "ICloudBackupServiceTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func test_backupIfNeeded_skipsWrite_whenICloudUnavailable() async {
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, available: false, destination: destination, userDefaults: freshUserDefaults())

        await service.backupIfNeeded(reason: .didEnterBackground)

        XCTAssertEqual(destination.writeCallCount, 0)
    }

    func test_backupIfNeeded_writes_onFirstBackup_whenNoPriorBackupExists() async {
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, destination: destination, userDefaults: freshUserDefaults())

        await service.backupIfNeeded(reason: .didEnterBackground)

        XCTAssertEqual(destination.writeCallCount, 1)
    }

    func test_backupIfNeeded_throttleBoundaries() async {
        let baseTime = Date()
        let userDefaults = freshUserDefaults()
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: baseTime)
        let service = makeService(clock: clock, destination: destination, userDefaults: userDefaults)

        // Seed an initial backup at baseTime.
        setStoreModificationDate(baseTime)
        await service.backupIfNeeded(reason: .didEnterBackground)
        XCTAssertEqual(destination.writeCallCount, 1)

        // 59 minutes later, data changed: throttle NOT elapsed -> no backup.
        clock.fixedNow = baseTime.addingTimeInterval(59 * 60)
        setStoreModificationDate(clock.fixedNow)
        await service.backupIfNeeded(reason: .didEnterBackground)
        XCTAssertEqual(destination.writeCallCount, 1, "59 minutes: should not back up yet")

        // 59 minutes 59 seconds later, data changed: still not elapsed -> no backup.
        clock.fixedNow = baseTime.addingTimeInterval(59 * 60 + 59)
        setStoreModificationDate(clock.fixedNow)
        await service.backupIfNeeded(reason: .didEnterBackground)
        XCTAssertEqual(destination.writeCallCount, 1, "59m59s: should not back up yet")

        // 60 minutes later, data changed: throttle elapsed -> backup happens.
        clock.fixedNow = baseTime.addingTimeInterval(60 * 60)
        setStoreModificationDate(clock.fixedNow)
        await service.backupIfNeeded(reason: .didEnterBackground)
        XCTAssertEqual(destination.writeCallCount, 2, "60 minutes: should back up")
    }

    func test_backupIfNeeded_skipsWrite_whenNoDataChangedSinceLastBackup() async {
        let baseTime = Date()
        let userDefaults = freshUserDefaults()
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: baseTime)
        let service = makeService(clock: clock, destination: destination, userDefaults: userDefaults)

        setStoreModificationDate(baseTime)
        await service.backupIfNeeded(reason: .didEnterBackground)
        XCTAssertEqual(destination.writeCallCount, 1)

        // Two hours later, but the store file was NOT modified again.
        clock.fixedNow = baseTime.addingTimeInterval(2 * 3600)
        await service.backupIfNeeded(reason: .didEnterBackground)
        XCTAssertEqual(destination.writeCallCount, 1, "no data change means no backup even if throttle elapsed")
    }

    func test_backupIfNeeded_manualReason_ignoresThrottleAndAlwaysWrites() async {
        let baseTime = Date()
        let userDefaults = freshUserDefaults()
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: baseTime)
        let service = makeService(clock: clock, destination: destination, userDefaults: userDefaults)

        setStoreModificationDate(baseTime)
        await service.backupIfNeeded(reason: .manual)
        XCTAssertEqual(destination.writeCallCount, 1)

        // 1 second later: manual should still force a write even though throttle has not elapsed.
        clock.fixedNow = baseTime.addingTimeInterval(1)
        await service.backupIfNeeded(reason: .manual)
        XCTAssertEqual(destination.writeCallCount, 2)
    }

    func test_manualBackupNow_writesImmediately() async throws {
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, destination: destination, userDefaults: freshUserDefaults())

        try await service.manualBackupNow()

        XCTAssertEqual(destination.writeCallCount, 1)
        XCTAssertEqual(destination.lastWrittenURL, tempStoreURL)
    }

    // MARK: - manual backup fails when iCloud is unavailable

    func test_manualBackupNow_throwsICloudUnavailable_whenICloudUnavailable() async {
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, available: false, destination: destination, userDefaults: freshUserDefaults())

        do {
            try await service.manualBackupNow()
            XCTFail("expected manualBackupNow to throw when iCloud is unavailable")
        } catch ICloudBackupServiceError.iCloudUnavailable {
            // expected
        } catch {
            XCTFail("expected .iCloudUnavailable, got \(error)")
        }

        XCTAssertEqual(destination.writeCallCount, 0, "must not write a snapshot when iCloud is unavailable")
    }

    func test_restoreLatestSnapshot_copiesSnapshotOverStore() async throws {
        let destination = FakeBackupDestination()
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: snapshotURL.path, contents: Data("restored".utf8))
        destination.snapshotURL = snapshotURL
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, destination: destination, userDefaults: freshUserDefaults())

        try await service.restoreLatestSnapshot()

        let restoredData = try Data(contentsOf: tempStoreURL)
        XCTAssertEqual(String(data: restoredData, encoding: .utf8), "restored")
    }

    // MARK: - 8.3 reload store after restore

    func test_restoreLatestSnapshot_reloadsStore_afterCopyingSnapshot() async throws {
        let destination = FakeBackupDestination()
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: snapshotURL.path, contents: Data("restored".utf8))
        destination.snapshotURL = snapshotURL
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        let reloadCounter = ReloadStoreCallCounter()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, destination: destination, reloadStoreCallCount: reloadCounter, userDefaults: freshUserDefaults())

        try await service.restoreLatestSnapshot()

        XCTAssertEqual(reloadCounter.count, 1)
    }

    // MARK: - 8.5 schema compatibility check before restore

    func test_restoreLatestSnapshot_abortsWithoutModifyingStore_whenSnapshotSchemaIncompatible() async throws {
        let destination = FakeBackupDestination()
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: snapshotURL.path, contents: Data("incompatible".utf8))
        destination.snapshotURL = snapshotURL
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        let reloadCounter = ReloadStoreCallCounter()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(
            clock: clock,
            destination: destination,
            schemaCompatibilityChecking: FakeStoreSchemaCompatibilityChecker(compatible: false),
            reloadStoreCallCount: reloadCounter,
            userDefaults: freshUserDefaults()
        )

        do {
            try await service.restoreLatestSnapshot()
            XCTFail("expected restore to throw for an incompatible schema")
        } catch ICloudBackupServiceError.incompatibleSnapshotSchema {
            // expected
        }

        let storeData = try Data(contentsOf: tempStoreURL)
        XCTAssertEqual(String(data: storeData, encoding: .utf8), "test", "local store must be untouched when schema is incompatible")
        XCTAssertEqual(reloadCounter.count, 0, "must not reload a store that was never touched")
    }

    // MARK: - restore tries the snapshot out before replacing the store

    private func makeSnapshot(_ contents: String, sidecars: [String: String] = [:]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: url.path, contents: Data(contents.utf8))
        for (suffix, text) in sidecars {
            FileManager.default.createFile(atPath: url.path + suffix, contents: Data(text.utf8))
        }
        addTeardownBlock {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        return url
    }

    func test_restore_tries_a_copy_of_the_snapshot_not_the_snapshot_itself_and_leaves_no_copy_behind() async throws {
        let destination = FakeBackupDestination()
        let snapshotURL = try makeSnapshot("restored")
        destination.snapshotURL = snapshotURL
        let verifier = FakeStoreMigrationVerifier()
        let service = makeService(
            clock: FakeBackupClock(fixedNow: Date()), destination: destination, migrationVerifier: verifier,
            userDefaults: freshUserDefaults())

        try await service.restoreLatestSnapshot()

        let verified = try XCTUnwrap(verifier.verifiedURLs.first)
        XCTAssertEqual(verifier.verifiedURLs.count, 1)
        XCTAssertNotEqual(verified, snapshotURL, "the snapshot in iCloud must not be the file that gets upgraded")
        XCTAssertTrue(verified.path.hasPrefix(stagingDirectory.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stagingDirectory.path), [], "no temporary copy is left")
    }

    func test_restore_replaces_the_store_with_what_was_verified_even_when_icloud_changes_in_between() async throws {
        let destination = FakeBackupDestination()
        let snapshotURL = try makeSnapshot("verified")
        destination.snapshotURL = snapshotURL
        let verifier = FakeStoreMigrationVerifier()
        // Another device writes a new snapshot while the copy is being tried out.
        verifier.onVerify = { _ in try? Data("replaced in iCloud".utf8).write(to: snapshotURL) }
        let service = makeService(
            clock: FakeBackupClock(fixedNow: Date()), destination: destination, migrationVerifier: verifier,
            userDefaults: freshUserDefaults())

        try await service.restoreLatestSnapshot()

        XCTAssertEqual(String(data: try Data(contentsOf: tempStoreURL), encoding: .utf8), "verified")
    }

    func test_restore_does_not_replace_the_store_when_the_snapshot_cannot_be_migrated() async throws {
        let destination = FakeBackupDestination()
        destination.snapshotURL = try makeSnapshot("cannot be opened")
        let verifier = FakeStoreMigrationVerifier()
        verifier.shouldFail = true
        let reloadCounter = ReloadStoreCallCounter()
        let service = makeService(
            clock: FakeBackupClock(fixedNow: Date()), destination: destination, migrationVerifier: verifier,
            reloadStoreCallCount: reloadCounter, userDefaults: freshUserDefaults())

        do {
            try await service.restoreLatestSnapshot()
            XCTFail("expected restore to throw when the snapshot cannot be migrated")
        } catch ICloudBackupServiceError.snapshotMigrationFailed {
            // expected
        }

        XCTAssertEqual(String(data: try Data(contentsOf: tempStoreURL), encoding: .utf8), "test", "the store is untouched")
        XCTAssertEqual(reloadCounter.count, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stagingDirectory.path), [], "no temporary copy is left")
    }

    func test_restore_checks_compatibility_on_the_copy() async throws {
        final class RecordingChecker: StoreSchemaCompatibilityChecking {
            private(set) var checked: [URL] = []
            func isCompatible(storeAt url: URL) -> Bool {
                checked.append(url)
                return true
            }
        }
        let destination = FakeBackupDestination()
        let snapshotURL = try makeSnapshot("restored")
        destination.snapshotURL = snapshotURL
        let checker = RecordingChecker()
        let service = makeService(
            clock: FakeBackupClock(fixedNow: Date()), destination: destination, schemaCompatibilityChecking: checker,
            userDefaults: freshUserDefaults())

        try await service.restoreLatestSnapshot()

        XCTAssertEqual(checker.checked.count, 1)
        XCTAssertNotEqual(checker.checked.first, snapshotURL)
    }

    func test_restore_reads_every_snapshot_file_through_the_coordinator_and_skips_missing_sidecars() async throws {
        let destination = FakeBackupDestination()
        let snapshotURL = try makeSnapshot("main", sidecars: ["-wal": "wal"])
        destination.snapshotURL = snapshotURL
        let coordinator = FakeFileCoordinator()
        let service = makeService(
            clock: FakeBackupClock(fixedNow: Date()), destination: destination, fileCoordinator: coordinator,
            userDefaults: freshUserDefaults())

        try await service.restoreLatestSnapshot()

        XCTAssertEqual(coordinator.coordinatedReads, [snapshotURL, URL(fileURLWithPath: snapshotURL.path + "-wal")])
        XCTAssertEqual(String(data: try Data(contentsOf: URL(fileURLWithPath: tempStoreURL.path + "-wal")), encoding: .utf8), "wal")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempStoreURL.path + "-shm"))
        try? FileManager.default.removeItem(atPath: tempStoreURL.path + "-wal")
    }

    // MARK: - 8.8 availability check before restore

    func test_restoreLatestSnapshot_doesNotAccessSnapshot_whenICloudUnavailable() async {
        let destination = FakeBackupDestination()
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: snapshotURL.path, contents: Data("restored".utf8))
        destination.snapshotURL = snapshotURL
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, available: false, destination: destination, userDefaults: freshUserDefaults())

        do {
            try await service.restoreLatestSnapshot()
            XCTFail("expected restore to throw when iCloud is unavailable")
        } catch ICloudBackupServiceError.iCloudUnavailable {
            // expected
        } catch {
            XCTFail("expected .iCloudUnavailable, got \(error)")
        }

        let storeData = try? Data(contentsOf: tempStoreURL)
        XCTAssertEqual(storeData.flatMap { String(data: $0, encoding: .utf8) }, "test", "must not touch the store when iCloud is unavailable")
    }

    // MARK: - 8.6 serialized backup/restore (actor isolation)

    func test_concurrentManualBackupCalls_doNotProduceCorruptSnapshot() async throws {
        let destination = FakeBackupDestination()
        let clock = FakeBackupClock(fixedNow: Date())
        let service = makeService(clock: clock, destination: destination, userDefaults: freshUserDefaults())

        // Fire two manual backups concurrently without awaiting the first before starting
        // the second. Because `DefaultICloudBackupService` is an actor, both calls are
        // serialized on the actor instead of racing on the same store/snapshot files.
        async let first: () = service.manualBackupNow()
        async let second: () = service.manualBackupNow()
        _ = try await (first, second)

        XCTAssertEqual(destination.writeCallCount, 2, "both calls should complete, serialized rather than corrupting shared state")
    }
}

final class RestoreFailureAlertTests: XCTestCase {
    func test_each_restore_failure_says_that_the_current_data_is_unchanged() {
        let errors: [Error] = [
            ICloudBackupServiceError.incompatibleSnapshotSchema,
            ICloudBackupServiceError.snapshotMigrationFailed,
            ICloudBackupServiceError.iCloudUnavailable,
        ]

        let messages = errors.map { SceneDelegate.restoreFailureAlert(for: $0).message ?? "" }

        XCTAssertTrue(messages.allSatisfy { $0.contains("目前的資料沒有變動") })
        XCTAssertEqual(Set(messages).count, 3, "the two snapshot failures and any other failure each say their own thing")
    }

    func test_the_failure_alert_has_one_dismiss_button() {
        let alert = SceneDelegate.restoreFailureAlert(for: ICloudBackupServiceError.snapshotMigrationFailed)

        XCTAssertEqual(alert.title, "還原失敗")
        XCTAssertEqual(alert.actions.map(\.title), ["好"])
    }
}
