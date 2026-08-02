//
//  LocalDBServiceCrashFixesTests.swift
//  MyTaiwanStockTests
//

import XCTest
import CoreData
import CloudKit
@testable import MyTaiwanStock

final class LocalDBServiceCrashFixesTests: XCTestCase {

    // MARK: - 2.1 URL.storeURL returns nil instead of crashing

    func test_storeURL_returnsNil_whenAppGroupDoesNotExist() {
        let result = URL.storeURL(for: "group.does.not.exist.\(UUID().uuidString)", databaseName: "Whatever")
        XCTAssertNil(result)
    }

    // MARK: - 2.3 saveContext posts .dataSaveDidFail instead of crashing

    func test_saveContext_postsDataSaveDidFailNotification_onValidationError() {
        let originalContainer = LocalDBService.shared.container
        defer { LocalDBService.shared.container = originalContainer }

        // Reuse the already-resolved model object from the running singleton instead of
        // constructing a new NSPersistentContainer(name:), which re-merges every loaded
        // bundle's model and hits an ambiguous-entity error in the test host environment.
        let inMemoryContainer = NSPersistentContainer(
            name: "MyTaiwanStock",
            managedObjectModel: originalContainer.managedObjectModel
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        inMemoryContainer.persistentStoreDescriptions = [description]

        let loadExpectation = expectation(description: "load in-memory store")
        inMemoryContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5)

        LocalDBService.shared.container = inMemoryContainer

        // `List.name` is a non-optional attribute in the model; explicitly nil-ing it
        // via KVC forces a mandatory-property validation error on save. Entity is looked
        // up by name (not the `List(context:)` convenience init) to avoid the test host's
        // ambiguous class-to-entity mapping when multiple compiled models are loaded.
        let list = NSEntityDescription.insertNewObject(forEntityName: "List", into: inMemoryContainer.viewContext)
        list.setValue(nil, forKey: "name")

        let notificationExpectation = XCTNSNotificationExpectation(name: .dataSaveDidFail)

        LocalDBService.shared.saveContext()

        wait(for: [notificationExpectation], timeout: 5)
    }

    // MARK: - 2.4 loadPersistentStores CKError classification (pure function, no real store load)

    func test_knownRecoverableCKErrorCode_recognizesAllSixKnownCodes() {
        let knownCodes: [CKError.Code] = [
            .notAuthenticated,
            .networkUnavailable,
            .serverRecordChanged,
            .zoneNotFound,
            .partialFailure,
            .quotaExceeded,
        ]

        for code in knownCodes {
            let error = NSError(domain: CKError.errorDomain, code: code.rawValue)
            XCTAssertEqual(
                LocalDBService.knownRecoverableCKErrorCode(for: error),
                code,
                "expected \(code) to be classified as recoverable"
            )
        }
    }

    func test_knownRecoverableCKErrorCode_returnsNil_forUnknownCKError() {
        let error = NSError(domain: CKError.errorDomain, code: CKError.Code.internalError.rawValue)
        XCTAssertNil(LocalDBService.knownRecoverableCKErrorCode(for: error))
    }

    func test_knownRecoverableCKErrorCode_returnsNil_forNonCloudKitDomain() {
        let error = NSError(domain: NSCocoaErrorDomain, code: CKError.Code.notAuthenticated.rawValue)
        XCTAssertNil(LocalDBService.knownRecoverableCKErrorCode(for: error))
    }
}
