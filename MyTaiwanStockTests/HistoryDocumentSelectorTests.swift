//
//  HistoryDocumentSelectorTests.swift
//  MyTaiwanStockTests
//
//  The online database finds a record by email and millisecond time only. Two records that
//  share a millisecond must not make a delete remove the wrong one.
//

import XCTest
@testable import MyTaiwanStock

final class HistoryDocumentSelectorTests: XCTestCase {

    private func document(
        _ id: String, _ stockNo: String, status: Int = 0, price: Double = 100, amount: Int = 5
    ) -> OnlineHistoryDocument {
        OnlineHistoryDocument(id: id, stockNo: stockNo, status: status, price: price, amount: amount)
    }

    private func record(_ stockNo: String, status: Int = 0, price: Double = 100, amount: Int = 5) -> DeletedHistoryRecord {
        DeletedHistoryRecord(stockNo: stockNo, status: status, price: price, amount: amount)
    }

    func test_picks_the_document_of_the_deleted_stock_when_two_stocks_share_a_time() {
        let documents = [document("a", "0050"), document("b", "2344")]

        XCTAssertEqual(HistoryDocumentSelector.documentID(toDelete: record("2344"), among: documents), "b")
        XCTAssertEqual(HistoryDocumentSelector.documentID(toDelete: record("0050"), among: documents), "a")
    }

    func test_distinguishes_a_buy_from_a_sell_of_the_same_stock() {
        let documents = [document("buy", "2330", status: 0), document("sell", "2330", status: 1)]

        XCTAssertEqual(HistoryDocumentSelector.documentID(toDelete: record("2330", status: 1), among: documents), "sell")
    }

    func test_prefers_the_document_with_the_same_price_and_shares() {
        let documents = [
            document("x", "2330", price: 2470, amount: 1),
            document("y", "2330", price: 2500, amount: 3),
        ]

        XCTAssertEqual(HistoryDocumentSelector.documentID(toDelete: record("2330", price: 2500, amount: 3), among: documents), "y")
    }

    func test_deletes_nothing_when_no_document_belongs_to_the_record() {
        let documents = [document("a", "0050"), document("b", "2344")]

        XCTAssertNil(HistoryDocumentSelector.documentID(toDelete: record("2330"), among: documents))
        XCTAssertNil(HistoryDocumentSelector.documentID(toDelete: record("0050", status: 1), among: documents))
        XCTAssertNil(HistoryDocumentSelector.documentID(toDelete: record("2330"), among: []))
    }

    func test_a_single_matching_document_is_chosen_even_if_price_differs_slightly() {
        // The local price is a Float and the online one a Double, so an exact price match is a preference, not a requirement.
        let documents = [document("only", "2330", price: 2470.0000001)]

        XCTAssertEqual(HistoryDocumentSelector.documentID(toDelete: record("2330", price: 2470), among: documents), "only")
    }

    func test_identical_documents_delete_exactly_one() {
        let documents = [document("first", "2330"), document("second", "2330")]

        XCTAssertEqual(HistoryDocumentSelector.documentID(toDelete: record("2330"), among: documents), "first")
    }
}
