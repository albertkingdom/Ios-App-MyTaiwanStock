//
//  PendingImportStore.swift
//  MyTaiwanStock
//
//  Shared by the app and the share extension, so it only depends on Foundation.
//

import Foundation

enum PendingImportError: Error {
    /// The draft was already committed or discarded.
    case draftFinished
    /// The draft has no images, or its images are not numbered 0, 1, 2 without gaps.
    case incompleteDraft
}

/// A finished batch of shared screenshots that waits to be imported.
struct PendingImportBatch: Equatable {
    let folderURL: URL
    let createdAt: Date
    /// The image files in the order they were shared.
    let imageURLs: [URL]
}

/// The folder in the shared App Group container through which the share extension hands screenshots to
/// the app. Screenshots show brokerage trades, so they stay as short-lived and as protected as possible:
/// excluded from backup, unreadable while the device is locked, and deleted after 24 hours at the latest
/// (the app calls `purgeStale` whenever it looks for batches).
///
/// A share is written as a draft folder first and renamed to a batch folder when every image has been
/// copied, so a reader never sees a half-written batch. Both names start with the creation time in
/// milliseconds, which orders batches and expires them without looking at file attributes.
final class PendingImportStore {
    static let appGroupIdentifier = "group.a2006mike.myTaiwanStock"
    static let maximumBatchAge: TimeInterval = 24 * 60 * 60
    static let maximumDraftAge: TimeInterval = 60 * 60
    /// A folder dated further in the future than this means the clock was set back, so it never expires
    /// on its own; it is deleted instead.
    static let maximumClockSkew: TimeInterval = 5 * 60
    private static let draftPrefix = ".tmp-"

    let rootURL: URL
    fileprivate let fileManager: FileManager
    private let now: () -> Date
    private let protection: (URL) throws -> Void

    /// `protection` applies the file protection to a file or folder. The default makes it unreadable while
    /// the device is locked; tests pass their own because the simulator does not implement file protection.
    init(
        containerURL: URL,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        protection: ((URL) throws -> Void)? = nil
    ) {
        self.rootURL = containerURL.appendingPathComponent("PendingImports", isDirectory: true)
        self.fileManager = fileManager
        self.now = now
        self.protection = protection ?? { url in
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
    }

    /// The store inside the App Group container, or nil when the container cannot be accessed.
    static func forAppGroup(_ identifier: String = appGroupIdentifier, fileManager: FileManager = .default) -> PendingImportStore? {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) else { return nil }
        return PendingImportStore(containerURL: containerURL, fileManager: fileManager)
    }

    // MARK: writing

    func beginDraft() throws -> PendingImportDraft {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var root = rootURL
        try root.setResourceValues(values)
        try protect(rootURL)

        let folderURL = rootURL.appendingPathComponent(Self.draftPrefix + Self.folderName(for: now()), isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
        try protect(folderURL)
        return PendingImportDraft(store: self, folderURL: folderURL)
    }

    // MARK: reading

    /// Finished batches, oldest first. A batch that cannot be listed, for example because the device is
    /// locked, is left out and stays on disk.
    func batches() -> [PendingImportBatch] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: rootURL.path) else { return [] }
        return names
            .compactMap { name -> PendingImportBatch? in
                guard !name.hasPrefix(Self.draftPrefix), let createdAt = Self.date(fromFolderName: name) else { return nil }
                let folderURL = rootURL.appendingPathComponent(name, isDirectory: true)
                let images = numberedImages(in: folderURL)
                guard !images.isEmpty else { return nil }
                return PendingImportBatch(folderURL: folderURL, createdAt: createdAt, imageURLs: images.map(\.url))
            }
            .sorted { ($0.createdAt, $0.folderURL.lastPathComponent) < ($1.createdAt, $1.folderURL.lastPathComponent) }
    }

    // MARK: deleting

    func delete(_ batch: PendingImportBatch) {
        try? fileManager.removeItem(at: batch.folderURL)
    }

    /// Deletes batches older than 24 hours and draft folders older than 1 hour (left behind when the
    /// extension was ended before it finished).
    func purgeStale() {
        guard let names = try? fileManager.contentsOfDirectory(atPath: rootURL.path) else { return }
        let current = now()
        for name in names {
            let isDraft = name.hasPrefix(Self.draftPrefix)
            let timestampName = isDraft ? String(name.dropFirst(Self.draftPrefix.count)) : name
            guard let createdAt = Self.date(fromFolderName: timestampName) else { continue }
            let limit = isDraft ? Self.maximumDraftAge : Self.maximumBatchAge
            let age = current.timeIntervalSince(createdAt)
            if age > limit || age < -Self.maximumClockSkew {
                try? fileManager.removeItem(at: rootURL.appendingPathComponent(name))
            }
        }
    }

    // MARK: helpers

    fileprivate func protect(_ url: URL) throws {
        try protection(url)
    }

    fileprivate func finish(_ draftFolder: URL) throws -> PendingImportBatch {
        let images = numberedImages(in: draftFolder)
        guard !images.isEmpty, images.map(\.index) == Array(0..<images.count) else {
            throw PendingImportError.incompleteDraft
        }
        try protect(draftFolder)

        let createdAt = now()
        let folderURL = rootURL.appendingPathComponent(Self.folderName(for: createdAt), isDirectory: true)
        try fileManager.moveItem(at: draftFolder, to: folderURL)
        return PendingImportBatch(
            folderURL: folderURL,
            createdAt: createdAt,
            imageURLs: images.map { folderURL.appendingPathComponent($0.url.lastPathComponent) })
    }

    /// The files named "<index>" or "<index>.<extension>", sorted by index.
    private func numberedImages(in folderURL: URL) -> [(index: Int, url: URL)] {
        guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { return [] }
        return files
            .compactMap { url -> (index: Int, url: URL)? in
                guard let index = Int(url.deletingPathExtension().lastPathComponent) else { return nil }
                return (index, url)
            }
            .sorted { $0.index < $1.index }
    }

    private static func folderName(for date: Date) -> String {
        String(format: "%013lld-%@", Int64(date.timeIntervalSince1970 * 1000), UUID().uuidString)
    }

    private static func date(fromFolderName name: String) -> Date? {
        guard let dash = name.firstIndex(of: "-"), let milliseconds = Int64(name[..<dash]) else { return nil }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

/// One share being written. Images may be added from several threads, in any order, as long as the
/// indices run from 0 without gaps by the time `commit` is called.
final class PendingImportDraft {
    private let store: PendingImportStore
    private let folderURL: URL
    private let lock = NSLock()
    private var isFinished = false

    fileprivate init(store: PendingImportStore, folderURL: URL) {
        self.store = store
        self.folderURL = folderURL
    }

    /// Copies a file into the draft. The source may be a temporary file that disappears after the caller
    /// returns, so the copy has to happen before then.
    func addImage(copying sourceURL: URL, at index: Int) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { throw PendingImportError.draftFinished }

        let fileExtension = sourceURL.pathExtension
        let name = fileExtension.isEmpty ? "\(index)" : "\(index).\(fileExtension)"
        let destination = folderURL.appendingPathComponent(name)
        try store.fileManager.copyItem(at: sourceURL, to: destination)
        try store.protect(destination)
    }

    /// Turns the draft into a batch. On failure the draft is still there; call `discard`.
    func commit() throws -> PendingImportBatch {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { throw PendingImportError.draftFinished }

        let batch = try store.finish(folderURL)
        isFinished = true
        return batch
    }

    /// Removes the draft with everything copied into it.
    func discard() {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { return }
        isFinished = true
        try? store.fileManager.removeItem(at: folderURL)
    }
}
