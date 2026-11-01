//
//  StoreSchemaCompatibilityCheckerTests.swift
//  MyTaiwanStockTests
//

import CoreData
import Foundation
import Testing

@testable import MyTaiwanStock

struct StoreSchemaCompatibilityCheckerTests {
    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("checker-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    /// An empty SQLite store that was created with `model`.
    private func makeStore(model: NSManagedObjectModel, at url: URL) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        try coordinator.remove(store)
    }

    private func foreignModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "Unrelated"
        let attribute = NSAttributeDescription()
        attribute.name = "title"
        attribute.attributeType = .stringAttributeType
        entity.properties = [attribute]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    @Test func aStoreOfAnEarlierModelVersionIsCompatibleWhenThatVersionIsKnown() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("first.sqlite")
            try LegacyStore.createFirstVersionStore(at: url, records: [])
            let checker = CoreDataSchemaCompatibilityChecker(knownModels: {
                [try! LegacyStore.firstVersion(), try! LegacyStore.secondVersion()]
            })

            #expect(checker.isCompatible(storeAt: url))
        }
    }

    @Test func aStoreOfTheCurrentVersionIsCompatible() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("second.sqlite")
            try makeStore(model: try LegacyStore.secondVersion(), at: url)
            let checker = CoreDataSchemaCompatibilityChecker(knownModels: {
                [try! LegacyStore.firstVersion(), try! LegacyStore.secondVersion()]
            })

            #expect(checker.isCompatible(storeAt: url))
        }
    }

    @Test func aStoreOfAVersionThatIsNotKnownIsNotCompatible() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("first.sqlite")
            try LegacyStore.createFirstVersionStore(at: url, records: [])
            let onlyCurrent = CoreDataSchemaCompatibilityChecker(knownModels: { [try! LegacyStore.secondVersion()] })

            #expect(!onlyCurrent.isCompatible(storeAt: url))
        }
    }

    @Test func aStoreOfAnotherModelIsNotCompatible() throws {
        try withDirectory { directory in
            let url = directory.appendingPathComponent("other.sqlite")
            try makeStore(model: foreignModel(), at: url)
            let checker = CoreDataSchemaCompatibilityChecker(knownModels: {
                [try! LegacyStore.firstVersion(), try! LegacyStore.secondVersion()]
            })

            #expect(!checker.isCompatible(storeAt: url))
        }
    }

    @Test func aMissingOrBrokenFileIsNotCompatible() throws {
        try withDirectory { directory in
            let checker = CoreDataSchemaCompatibilityChecker(knownModels: { [try! LegacyStore.secondVersion()] })
            let broken = directory.appendingPathComponent("broken.sqlite")
            try Data("not a database".utf8).write(to: broken)

            #expect(!checker.isCompatible(storeAt: directory.appendingPathComponent("missing.sqlite")))
            #expect(!checker.isCompatible(storeAt: broken))
        }
    }

    @Test func theBundledModelsAreBothVersions() {
        #expect(BundledModels.all().count == 2)
    }

    @Test func aFirstVersionCopyIsUpgradedByTheVerifierAndABrokenOneIsRefused() throws {
        try withDirectory { directory in
            let upgradable = directory.appendingPathComponent("upgradable.sqlite")
            try LegacyStore.createFirstVersionStore(at: upgradable, records: [
                .init(stockNo: "0050", status: 0, shares: 1000, price: 100, date: Date()),
            ])
            let broken = directory.appendingPathComponent("broken.sqlite")
            try Data("not a database".utf8).write(to: broken)
            let verifier = CoreDataStoreMigrationVerifier(currentModel: { try! LegacyStore.secondVersion() })

            try verifier.verifyStoreCanBeOpened(at: upgradable)
            #expect(throws: (any Error).self) { try verifier.verifyStoreCanBeOpened(at: broken) }

            // The copy that was tried out has been upgraded to the current model.
            let checker = CoreDataSchemaCompatibilityChecker(knownModels: { [try! LegacyStore.secondVersion()] })
            #expect(checker.isCompatible(storeAt: upgradable))
        }
    }
}
