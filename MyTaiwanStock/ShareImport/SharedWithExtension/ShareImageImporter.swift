//
//  ShareImageImporter.swift
//  MyTaiwanStock
//
//  Shared by the app and the share extension, so it only depends on Foundation.
//

import Foundation
import UniformTypeIdentifiers

enum ShareImageImporterError: Error {
    /// The share holds no image.
    case noImages
    /// One image could not be loaded or copied.
    case imageUnavailable
}

/// A share that is being copied. Cancelling it removes what was copied so far and the completion is
/// never called, so a share the user gave up on leaves nothing behind.
final class ShareImageImport {
    private let lock = NSLock()
    private var cancelled = false
    private var draft: PendingImportDraft?

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let draft = draft
        lock.unlock()
        draft?.discard()
    }

    fileprivate func attach(_ draft: PendingImportDraft) {
        lock.lock()
        self.draft = draft
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { draft.discard() }
    }
}

/// Copies the images of a share into a new batch of the pending import folder.
///
/// The extension has little memory, so images are copied as files and never decoded. Attachments load in
/// parallel and each temporary file disappears when its handler returns, so every copy happens inside the
/// handler. The images are numbered by their position among the shared images, not by the order in which
/// they finish loading.
enum ShareImageImporter {
    /// Calls `completion` on the main queue with the finished batch, or with the error after removing
    /// everything that was copied. Attachments that are not images are ignored. The returned object cancels
    /// the share; a cancelled share never calls `completion`.
    @discardableResult
    static func importImages(
        from providers: [NSItemProvider],
        into store: PendingImportStore,
        completion: @escaping (Result<PendingImportBatch, Error>) -> Void
    ) -> ShareImageImport {
        let handle = ShareImageImport()
        func finish(_ result: Result<PendingImportBatch, Error>) {
            guard !handle.isCancelled else { return }
            completion(result)
        }

        let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !imageProviders.isEmpty else {
            DispatchQueue.main.async { finish(.failure(ShareImageImporterError.noImages)) }
            return handle
        }

        let draft: PendingImportDraft
        do {
            draft = try store.beginDraft()
        } catch {
            DispatchQueue.main.async { finish(.failure(error)) }
            return handle
        }
        handle.attach(draft)

        let failure = FirstFailure()
        let group = DispatchGroup()
        for (index, provider) in imageProviders.enumerated() {
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                defer { group.leave() }
                guard let url else {
                    failure.record(error ?? ShareImageImporterError.imageUnavailable)
                    return
                }
                do {
                    try draft.addImage(copying: url, at: index)
                } catch {
                    failure.record(error)
                }
            }
        }

        group.notify(queue: .main) {
            if let error = failure.value {
                draft.discard()
                finish(.failure(error))
                return
            }
            do {
                let batch = try draft.commit()
                if handle.isCancelled {
                    // Cancelled after the last image was copied, so the batch exists and has to go too.
                    store.delete(batch)
                    return
                }
                completion(.success(batch))
            } catch {
                draft.discard()
                finish(.failure(error))
            }
        }
        return handle
    }
}

/// Keeps the first error reported from any of the loading threads.
private final class FirstFailure {
    private let lock = NSLock()
    private var first: Error?

    var value: Error? {
        lock.lock()
        defer { lock.unlock() }
        return first
    }

    func record(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        if first == nil { first = error }
    }
}
