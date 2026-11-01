//
//  InvestHistoryMigrationTests.swift
//  MyTaiwanStockTests
//

import CoreData
import Foundation
import Testing

@testable import MyTaiwanStock

/// Builds stores with the first version of the model, as an earlier release of the app saved them. The
/// records are written with key-value coding because the test target and the app each generate their own
/// `InvestHistory` class, and two models claiming the same class would make `entity()` ambiguous.
enum LegacyStore {
    struct Record {
        var stockNo: String
        var status: Int16
        var shares: Int16
        var price: Float
        var date: Date
    }

    static let modelBundle = Bundle(for: LocalDBService.self)

    static func model(named name: String) throws -> NSManagedObjectModel {
        let momd = try #require(modelBundle.url(forResource: "MyTaiwanStock", withExtension: "momd"))
        return try #require(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("\(name).mom")))
    }

    static func firstVersion() throws -> NSManagedObjectModel { try model(named: "MyTaiwanStock") }
    static func secondVersion() throws -> NSManagedObjectModel { try model(named: "MyTaiwanStock 2") }

    /// A SQLite store in the first model version, with the history tracking the app turns on.
    static func createFirstVersionStore(at url: URL, records: [Record]) throws {
        let model = try firstVersion()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [NSPersistentHistoryTrackingKey: true])
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let entity = try #require(model.entitiesByName["InvestHistory"])
        try context.performAndWait {
            for record in records {
                let object = NSManagedObject(entity: entity, insertInto: context)
                object.setValue(record.stockNo, forKey: "stockNo")
                object.setValue(record.status, forKey: "status")
                object.setValue(record.shares, forKey: "amount")
                object.setValue(record.price, forKey: "price")
                object.setValue(record.date, forKey: "date")
            }
            try context.save()
        }
        try coordinator.remove(store)
    }

    /// Opens a store the way the app does: the current model, automatic migration, history tracking.
    static func openWithCurrentModel(at url: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "MyTaiwanStock", managedObjectModel: try secondVersion())
        let description = NSPersistentStoreDescription(url: url)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        return container
    }

    static func makeTemporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("MyTaiwanStock.sqlite")
    }
}

struct InvestHistoryMigrationTests {
    private func withStoreURL(_ body: (URL) throws -> Void) throws {
        let url = LegacyStore.makeTemporaryStoreURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try body(url)
    }

    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    private var sampleRecords: [LegacyStore.Record] {
        [
            .init(stockNo: "0050", status: 0, shares: 1000, price: 100, date: day),
            .init(stockNo: "0050", status: 0, shares: 500, price: 110, date: day.addingTimeInterval(60)),
            .init(stockNo: "2330", status: 0, shares: 10, price: 757, date: day.addingTimeInterval(120)),
            .init(stockNo: "0050", status: 1, shares: 400, price: 105, date: day.addingTimeInterval(180)),
            .init(stockNo: "2330", status: 1, shares: 10, price: 760, date: day.addingTimeInterval(240)),
        ]
    }

    @Test func theCurrentModelIsTheSecondVersionWithOptionalFeeAndTax() throws {
        let entity = try #require(try LegacyStore.secondVersion().entitiesByName["InvestHistory"])

        for name in ["fee", "tax"] {
            let attribute = try #require(entity.attributesByName[name])
            #expect(attribute.attributeType == .integer32AttributeType)
            #expect(attribute.isOptional)
            #expect(attribute.defaultValue == nil)
        }
        #expect(try LegacyStore.firstVersion().entitiesByName["InvestHistory"]?.attributesByName["fee"] == nil)
    }

    @Test func recordsSurviveTheUpgradeWithUnknownFeeAndTax() throws {
        try withStoreURL { url in
            try LegacyStore.createFirstVersionStore(at: url, records: sampleRecords)

            let container = try LegacyStore.openWithCurrentModel(at: url)

            try container.viewContext.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "InvestHistory")
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
                let records = try container.viewContext.fetch(request)
                #expect(records.count == 5)
                #expect(records.map { $0.value(forKey: "stockNo") as? String } == ["0050", "0050", "2330", "0050", "2330"])
                #expect(records.map { $0.value(forKey: "status") as? Int16 } == [0, 0, 0, 1, 1])
                #expect(records.map { $0.value(forKey: "amount") as? Int16 } == [1000, 500, 10, 400, 10])
                #expect(records.map { $0.value(forKey: "price") as? Float } == [100, 110, 757, 105, 760])
                #expect(records.allSatisfy { $0.value(forKey: "fee") == nil && $0.value(forKey: "tax") == nil })
            }
        }
    }

    @Test func aRecordKeepsItsFeeAndTaxAfterTheUpgrade() throws {
        try withStoreURL { url in
            try LegacyStore.createFirstVersionStore(at: url, records: sampleRecords)
            let container = try LegacyStore.openWithCurrentModel(at: url)
            try container.viewContext.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "InvestHistory")
                request.fetchLimit = 1
                let record = try #require(try container.viewContext.fetch(request).first)
                record.setValue(NSNumber(value: 142), forKey: "fee")
                record.setValue(NSNumber(value: 0), forKey: "tax")
                try container.viewContext.save()
            }

            let reopened = try LegacyStore.openWithCurrentModel(at: url)

            try reopened.viewContext.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "InvestHistory")
                request.predicate = NSPredicate(format: "fee != nil")
                let withFee = try reopened.viewContext.fetch(request)
                #expect(withFee.count == 1)
                #expect((withFee.first?.value(forKey: "fee") as? NSNumber)?.intValue == 142)
                #expect((withFee.first?.value(forKey: "tax") as? NSNumber)?.intValue == 0, "a stored 0 is not unknown")
            }
        }
    }
}
