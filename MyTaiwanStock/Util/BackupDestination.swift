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
