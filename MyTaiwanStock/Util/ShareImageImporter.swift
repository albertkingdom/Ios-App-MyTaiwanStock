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

/// Copies the images of a share into a new batch of the pending import folder.
///
/// The extension has little memory, so images are copied as files and never decoded. Attachments load in
/// parallel and each temporary file disappears when its handler returns, so every copy happens inside the
/// handler. The images are numbered by their position among the shared images, not by the order in which
/// they finish loading.
enum ShareImageImporter {
    /// Calls `completion` on the main queue with the finished batch, or with the error after removing
    /// everything that was copied. Attachments that are not images are ignored.
    static func importImages(
        from providers: [NSItemProvider],
        into store: PendingImportStore,
        completion: @escaping (Result<PendingImportBatch, Error>) -> Void
    ) {
        let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !imageProviders.isEmpty else {
            DispatchQueue.main.async { completion(.failure(ShareImageImporterError.noImages)) }
            return
        }

        let draft: PendingImportDraft
        do {
            draft = try store.beginDraft()
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

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
                completion(.failure(error))
                return
            }
            do {
                completion(.success(try draft.commit()))
            } catch {
                draft.discard()
                completion(.failure(error))
            }
        }
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
