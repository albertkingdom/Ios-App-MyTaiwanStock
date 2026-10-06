//
//  HistoryDocumentSelector.swift
//  MyTaiwanStock
//

import Foundation

/// The fields of a buy/sell document in the online database that identify it besides its time.
struct OnlineHistoryDocument: Equatable {
    let id: String
    let stockNo: String
    let status: Int
    let price: Double
    let amount: Int
}

/// The buy/sell record the user deleted locally.
struct DeletedHistoryRecord: Equatable {
    let stockNo: String
    let status: Int
    let price: Double
    let amount: Int
}

/// Chooses which online document a local delete removes.
///
/// The query can only filter on email and time, and records written in the same millisecond share
/// both, so the first document returned is not necessarily the deleted record. The stock and the
/// direction must match, and among those the one with the same price and shares is preferred. When
/// no document belongs to the record nothing is deleted.
enum HistoryDocumentSelector {
    static func documentID(
        toDelete record: DeletedHistoryRecord, among documents: [OnlineHistoryDocument]
    ) -> String? {
        let candidates = documents.filter { $0.stockNo == record.stockNo && $0.status == record.status }
        // The local price is a Float and the online one a Double, so compare with a tolerance.
        let exact = candidates.first {
            abs($0.price - record.price) < 0.0001 && $0.amount == record.amount
        }
        return (exact ?? candidates.first)?.id
    }
}
