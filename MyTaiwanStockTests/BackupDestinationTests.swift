//
//  BackupDestinationTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

/// Records whether coordination actually happened, and only runs `writer` when told to —
/// letting tests prove that `CoordinatedFileReplace` never touches `FileManager` outside of
/// the coordinator's accessor closure.
final class FakeFileCoordinator: FileCoordinating {
    private(set) var coordinateWritingCallCount = 0
    private(set) var lastOptions: NSFileCoordinator.WritingOptions?
    var shouldInvokeWriter = true

    func coordinateWriting(itemAt url: URL, options: NSFileCoordinator.WritingOptions, byAccessor writer: (URL) throws -> Void) throws {
        coordinateWritingCallCount += 1
        lastOptions = options
        if shouldInvokeWriter {
            try writer(url)
        }
    }
}

final class BackupDestinationTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("BackupDestinationTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func write(_ string: String, to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data(string.utf8))
    }

    // MARK: - 8.1 NSFileCoordinator is actually used

    func test_replace_coordinatesTheWrite_ratherThanCallingFileManagerDirectly() throws {
        let source = tempDir.appendingPathComponent("source.sqlite")
        let destination = tempDir.appendingPathComponent("dest.sqlite")
        write("hello", to: source)

        let coordinator = FakeFileCoordinator()
        try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source, coordinator: coordinator)

        XCTAssertEqual(coordinator.coordinateWritingCallCount, 1)
        XCTAssertEqual(coordinator.lastOptions, .forReplacing)
    }

    func test_replace_writesNothing_whenCoordinatorNeverInvokesAccessor() throws {
        let source = tempDir.appendingPathComponent("source.sqlite")
        let destination = tempDir.appendingPathComponent("dest.sqlite")
        write("hello", to: source)

        let coordinator = FakeFileCoordinator()
        coordinator.shouldInvokeWriter = false
        try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source, coordinator: coordinator)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: destination.path),
            "the destination must only ever be written from inside the coordinator's accessor"
        )
    }

    func test_replace_removesDestinationViaCoordinator_whenSourceDoesNotExist() throws {
        let source = tempDir.appendingPathComponent("missing-source.sqlite")
        let destination = tempDir.appendingPathComponent("dest.sqlite")
        write("stale", to: destination)

        let coordinator = FakeFileCoordinator()
        try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source, coordinator: coordinator)

        XCTAssertEqual(coordinator.coordinateWritingCallCount, 1)
        XCTAssertEqual(coordinator.lastOptions, .forDeleting)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: - 8.4 atomic replace (no separate remove-then-copy window)

    func test_replace_overwritesExistingDestination_withSourceContent() throws {
        let source = tempDir.appendingPathComponent("source.sqlite")
        let destination = tempDir.appendingPathComponent("dest.sqlite")
        write("old", to: destination)
        write("new", to: source)

        try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source)

        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "new")
    }

    func test_replace_leavesNoTemporaryFilesBehind() throws {
        let source = tempDir.appendingPathComponent("source.sqlite")
        let destination = tempDir.appendingPathComponent("dest.sqlite")
        write("new", to: source)

        try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source)

        let remaining = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertFalse(remaining.contains { $0.hasPrefix(".tmp-") }, "temp file used for the atomic swap must be cleaned up")
    }

    // MARK: - 8.2 WAL/SHM sidecar files travel with the main snapshot

    func test_icloudDriveBackupDestination_write_copiesWalAndShmSidecarFiles() throws {
        let storeURL = tempDir.appendingPathComponent("live.sqlite")
        write("main-content", to: storeURL)
        write("wal-content", to: URL(fileURLWithPath: storeURL.path + "-wal"))
        write("shm-content", to: URL(fileURLWithPath: storeURL.path + "-shm"))

        let ubiquityDir = tempDir.appendingPathComponent("Ubiquity")
        try FileManager.default.createDirectory(at: ubiquityDir, withIntermediateDirectories: true)
        // `ICloudDriveBackupDestination` resolves its container via
        // `FileManager.url(forUbiquityContainerIdentifier:)`, which is unavailable/nil in
        // the test host (no real iCloud container). Exercise `SQLiteStoreFileSet` +
        // `CoordinatedFileReplace` directly against a plain temp directory instead — this is
        // the same code path `write(snapshotAt:)` delegates to internally.
        let destinationMain = ubiquityDir.appendingPathComponent("backup.sqlite")
        let sourceSet = SQLiteStoreFileSet(mainURL: storeURL)
        let destinationSet = SQLiteStoreFileSet(mainURL: destinationMain)
        for (source, destination) in zip(sourceSet.allURLs, destinationSet.allURLs) {
            try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source)
        }

        XCTAssertEqual(try String(contentsOf: destinationSet.mainURL, encoding: .utf8), "main-content")
        XCTAssertEqual(try String(contentsOf: destinationSet.walURL, encoding: .utf8), "wal-content")
        XCTAssertEqual(try String(contentsOf: destinationSet.shmURL, encoding: .utf8), "shm-content")
    }

    func test_sqliteStoreFileSet_restoreRemovesStaleSidecarFiles_whenSnapshotHasNone() throws {
        // Snapshot was checkpointed (no -wal/-shm), but the live store still has stale
        // sidecar files from before the restore — those must be cleared, not left behind
        // to be replayed against the newly-restored main file.
        let snapshotURL = tempDir.appendingPathComponent("snapshot.sqlite")
        write("restored-content", to: snapshotURL)

        let liveStoreURL = tempDir.appendingPathComponent("live.sqlite")
        write("old-content", to: liveStoreURL)
        write("stale-wal", to: URL(fileURLWithPath: liveStoreURL.path + "-wal"))
        write("stale-shm", to: URL(fileURLWithPath: liveStoreURL.path + "-shm"))

        let sourceSet = SQLiteStoreFileSet(mainURL: snapshotURL)
        let destinationSet = SQLiteStoreFileSet(mainURL: liveStoreURL)
        for (source, destination) in zip(sourceSet.allURLs, destinationSet.allURLs) {
            try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source)
        }

        XCTAssertEqual(try String(contentsOf: destinationSet.mainURL, encoding: .utf8), "restored-content")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationSet.walURL.path), "stale -wal must be removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationSet.shmURL.path), "stale -shm must be removed")
    }
}
