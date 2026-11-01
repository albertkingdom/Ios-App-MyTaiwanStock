//
//  PendingBatchImageSource.swift
//  MyTaiwanStock
//

import Foundation

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
