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

final class ICloudBackupServiceTests: XCTestCase {
    private var tempStoreURL: URL!

    override func setUp() {
        super.setUp()
        tempStoreURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ICloudBackupServiceTests-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: tempStoreURL.path, contents: Data("test".utf8))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempStoreURL)
        tempStoreURL = nil
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
        reloadStoreCallCount: ReloadStoreCallCounter = ReloadStoreCallCounter(),
        userDefaults: UserDefaults
    ) -> DefaultICloudBackupService {
        DefaultICloudBackupService(
            clock: clock,
            availabilityChecking: FakeICloudAvailabilityChecker(available: available),
            destination: destination,
            schemaCompatibilityChecking: schemaCompatibilityChecking,
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
