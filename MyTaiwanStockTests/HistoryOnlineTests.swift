//
//  HistoryOnlineTests.swift
//  MyTaiwanStockTests
//

import CoreData
import XCTest
@testable import MyTaiwanStock

final class HistoryOnlineTests: XCTestCase {
    private func json(of history: HistoryOnline) throws -> [String: Any] {
        let data = try JSONEncoder().encode(history)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func test_a_known_fee_and_tax_are_in_the_document() throws {
        let history = HistoryOnline(
            price: 757, amount: 10, stockNo: "2330", time: 1_800_000_000_000, email: "a@b.c", status: 1, fee: 6, tax: 22)

        let object = try json(of: history)

        XCTAssertEqual(object["fee"] as? Int, 6)
        XCTAssertEqual(object["tax"] as? Int, 22)
        XCTAssertEqual(object["stockNo"] as? String, "2330", "the existing fields stay")
    }

    func test_a_tax_of_zero_is_still_written() throws {
        let history = HistoryOnline(
            price: 100, amount: 1000, stockNo: "0050", time: 1, email: "a@b.c", status: 0, fee: 142, tax: 0)

        XCTAssertEqual(try json(of: history)["tax"] as? Int, 0)
    }

    func test_an_unknown_fee_and_tax_leave_the_keys_out() throws {
        let history = HistoryOnline(price: 100, amount: 1000, stockNo: "0050", time: 1, email: "a@b.c", status: 0)

        let object = try json(of: history)

        XCTAssertNil(object["fee"])
        XCTAssertNil(object["tax"])
    }
}

/// Saving a record stores its fee and tax locally and uploads them.
final class RecordFeeStorageTests: XCTestCase {
    private var originalContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        originalContainer = LocalDBService.shared.container
        let inMemory = NSPersistentContainer(name: "MyTaiwanStock", managedObjectModel: originalContainer.managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        inMemory.persistentStoreDescriptions = [description]
        inMemory.loadPersistentStores { _, error in XCTAssertNil(error) }
        LocalDBService.shared.container = inMemory
    }

    override func tearDown() {
        LocalDBService.shared.container = originalContainer
        super.tearDown()
    }

    func test_a_saved_record_keeps_its_fee_and_tax_and_uploads_them() throws {
        let online = MockOnlineDBSyncing()
        let service = NetworkServiceImpl(onLineDBService: online)

        service.saveNewRecord(
            stockNo: "2330", price: 757, amount: 10, reason: "", buyOrSellStatus: 1,
            date: Date(timeIntervalSince1970: 1_800_000_000), fee: 6, tax: 22)

        let saved = try XCTUnwrap(LocalDBService.shared.fetchHistoryFromDB(with: "2330").first)
        XCTAssertEqual(saved.fee?.intValue, 6)
        XCTAssertEqual(saved.tax?.intValue, 22)
        XCTAssertEqual(online.uploadedHistory.count, 1)
        XCTAssertEqual(online.uploadedHistory.first?.fee, 6)
        XCTAssertEqual(online.uploadedHistory.first?.tax, 22)
    }

    func test_a_record_saved_without_them_has_unknown_fee_and_tax() throws {
        let service = NetworkServiceImpl(onLineDBService: MockOnlineDBSyncing())

        service.saveNewRecord(
            stockNo: "2330", price: 757, amount: 10, reason: "", buyOrSellStatus: 0,
            date: Date(timeIntervalSince1970: 1_800_000_000), fee: nil, tax: nil)

        let saved = try XCTUnwrap(LocalDBService.shared.fetchHistoryFromDB(with: "2330").first)
        XCTAssertNil(saved.fee)
        XCTAssertNil(saved.tax)
    }

    func test_a_tax_of_zero_is_stored_as_zero_not_unknown() throws {
        let service = NetworkServiceImpl(onLineDBService: MockOnlineDBSyncing())

        service.saveNewRecord(
            stockNo: "0050", price: 100, amount: 1000, reason: "", buyOrSellStatus: 0,
            date: Date(timeIntervalSince1970: 1_800_000_000), fee: 142, tax: 0)

        let saved = try XCTUnwrap(LocalDBService.shared.fetchHistoryFromDB(with: "0050").first)
        XCTAssertEqual(saved.tax?.intValue, 0)
    }
}
