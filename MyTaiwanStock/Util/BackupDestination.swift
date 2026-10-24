//
//  BackupDestination.swift
//  MyTaiwanStock
//

import Foundation

protocol BackupDestination {
    func write(snapshotAt url: URL) throws
    func latestSnapshotURL() -> URL?
}

enum BackupDestinationError: Error {
    case ubiquityContainerUnavailable
}

/// A SQLite store file plus its WAL-mode sidecar files (`-wal`, `-shm`). Core Data's
/// SQLite store defaults to WAL journaling, so recently committed writes can live only in
/// the `-wal` file; copying just the main file silently drops them. Backup/restore always
/// operate on the full set so a snapshot (and its restore) is self-consistent.
struct SQLiteStoreFileSet {
    let mainURL: URL

    var walURL: URL {
        URL(fileURLWithPath: mainURL.path + "-wal")
    }
    var shmURL: URL {
        URL(fileURLWithPath: mainURL.path + "-shm")
    }

    var allURLs: [URL] { [mainURL, walURL, shmURL] }
}

/// Abstracts the exact `NSFileCoordinator` call `CoordinatedFileReplace` needs, so tests can
/// inject a fake and verify coordination actually happens (rather than `FileManager` being
/// called directly, uncoordinated).
protocol FileCoordinating {
    func coordinateWriting(itemAt url: URL, options: NSFileCoordinator.WritingOptions, byAccessor writer: (URL) throws -> Void) throws
    func coordinateReading(itemAt url: URL, options: NSFileCoordinator.ReadingOptions, byAccessor reader: (URL) throws -> Void) throws
}

extension NSFileCoordinator: FileCoordinating {
    func coordinateWriting(itemAt url: URL, options: NSFileCoordinator.WritingOptions, byAccessor writer: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var innerError: Error?
        coordinate(writingItemAt: url, options: options, error: &coordinatorError) { coordinatedURL in
            do {
                try writer(coordinatedURL)
            } catch {
                innerError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let innerError { throw innerError }
    }

    func coordinateReading(itemAt url: URL, options: NSFileCoordinator.ReadingOptions, byAccessor reader: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var innerError: Error?
        coordinate(readingItemAt: url, options: options, error: &coordinatorError) { coordinatedURL in
            do {
                try reader(coordinatedURL)
            } catch {
                innerError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let innerError { throw innerError }
    }
}

/// Copies a snapshot out of iCloud before it is used. The snapshot lives in the ubiquity container, so its
/// files may not be downloaded yet and another device may replace them at any time; reading each file
/// through the coordinator waits for the download, and copying all the files this way gives the restore a
/// set of its own that nothing else can change.
enum SnapshotStaging {
    /// Copies the snapshot's store file and its `-wal` and `-shm` files, when they exist, into each of
    /// `directories` in one coordinated read per file, and returns the copies. The store file must exist.
    @discardableResult
    static func copy(
        _ snapshot: SQLiteStoreFileSet,
        into directories: [URL],
        coordinator: FileCoordinating = NSFileCoordinator()
    ) throws -> [SQLiteStoreFileSet] {
        let targets = directories.map {
            SQLiteStoreFileSet(mainURL: $0.appendingPathComponent(snapshot.mainURL.lastPathComponent))
        }
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        for (index, source) in snapshot.allURLs.enumerated() {
            guard FileManager.default.fileExists(atPath: source.path) else {
                if index == 0 { throw CocoaError(.fileNoSuchFile) }
                continue
            }
            try coordinator.coordinateReading(itemAt: source, options: []) { coordinatedURL in
                for target in targets {
                    try FileManager.default.copyItem(at: coordinatedURL, to: target.allURLs[index])
                }
            }
        }
        return targets
    }
}

/// Coordinates atomic file replacement so callers racing on the same destination (e.g. the
/// iCloud sync daemon, or an overlapping backup/restore call) cannot observe or produce a
/// torn/partial file.
enum CoordinatedFileReplace {
    /// Atomically replaces `destination` with the contents of `source`. If `source` does
    /// not exist, any existing `destination` is removed instead — this keeps sidecar
    /// (`-wal`/`-shm`) files in sync when the source snapshot no longer has one (e.g. a
    /// checkpointed store with no pending WAL content).
    static func replace(
        destination: URL,
        withContentsOf source: URL,
        coordinator: FileCoordinating = NSFileCoordinator()
    ) throws {
        guard FileManager.default.fileExists(atPath: source.path) else {
            if FileManager.default.fileExists(atPath: destination.path) {
                try coordinator.coordinateWriting(itemAt: destination, options: .forDeleting) { coordinatedURL in
                    try FileManager.default.removeItem(at: coordinatedURL)
                }
            }
            return
        }

        let tempURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".tmp-\(UUID().uuidString)-\(destination.lastPathComponent)")
        try FileManager.default.copyItem(at: source, to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try coordinator.coordinateWriting(itemAt: destination, options: .forReplacing) { coordinatedURL in
            _ = try FileManager.default.replaceItemAt(coordinatedURL, withItemAt: tempURL)
        }
    }
}

struct ICloudDriveBackupDestination: BackupDestination {
    let ubiquityContainerIdentifier: String
    let snapshotFileName: String

    private func containerDocumentsURL() -> URL? {
        FileManager.default
            .url(forUbiquityContainerIdentifier: ubiquityContainerIdentifier)?
            .appendingPathComponent("Documents")
    }

    func write(snapshotAt url: URL) throws {
        guard let documentsURL = containerDocumentsURL() else {
            throw BackupDestinationError.ubiquityContainerUnavailable
        }
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let destinationURL = documentsURL.appendingPathComponent(snapshotFileName)

        let sourceSet = SQLiteStoreFileSet(mainURL: url)
        let destinationSet = SQLiteStoreFileSet(mainURL: destinationURL)
        for (source, destination) in zip(sourceSet.allURLs, destinationSet.allURLs) {
            try CoordinatedFileReplace.replace(destination: destination, withContentsOf: source)
        }
    }

    func latestSnapshotURL() -> URL? {
        guard let documentsURL = containerDocumentsURL() else { return nil }
        let destinationURL = documentsURL.appendingPathComponent(snapshotFileName)
        return FileManager.default.fileExists(atPath: destinationURL.path) ? destinationURL : nil
    }
}
