//
//  TradeImageSource.swift
//  MyTaiwanStock
//

import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The screenshots of one import. Images are loaded one at a time, so the flow holds a single image
/// in memory while it recognizes the text of each.
@MainActor
protocol TradeImageSource: AnyObject {
    var count: Int { get }
    func imageData(at index: Int) async throws -> Data
    /// Called once recognition has produced a result (trades, no trade, or an error that is shown to
    /// the user), before the preview or the message appears. It is not called when the recognition was
    /// interrupted, so a source can keep what it needs to run again.
    func recognitionDidFinish()
}

/// Images chosen in the system photo picker. The picker hands out copies, so there is nothing to clean up.
@MainActor
final class PhotoPickerImageSource: TradeImageSource {
    private let results: [PHPickerResult]

    init(results: [PHPickerResult]) {
        self.results = results
    }

    var count: Int { results.count }

    func imageData(at index: Int) async throws -> Data {
        let provider = results[index].itemProvider
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? TradeTextRecognizerError.invalidImage)
                }
            }
        }
    }

    func recognitionDidFinish() {}
}

/// The images of a batch the share extension left in the pending import folder. The batch is deleted as
/// soon as recognition has a result, so the screenshots do not stay on the device while the preview is open.
@MainActor
final class PendingBatchImageSource: TradeImageSource {
    let batch: PendingImportBatch
    private let store: PendingImportStore

    init(batch: PendingImportBatch, store: PendingImportStore) {
        self.batch = batch
        self.store = store
    }

    var count: Int { batch.imageURLs.count }

    func imageData(at index: Int) async throws -> Data {
        let url = batch.imageURLs[index]
        return try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
    }

    func recognitionDidFinish() {
        store.delete(batch)
    }
}
