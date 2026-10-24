//
//  StoreSchemaCompatibilityChecking.swift
//  MyTaiwanStock
//

import Foundation
import CoreData

protocol StoreSchemaCompatibilityChecking {
    /// Returns `true` when the SQLite store at `url` was created with a Core Data model
    /// compatible with the currently-running model, without opening the store.
    func isCompatible(storeAt url: URL) -> Bool
}

struct CoreDataSchemaCompatibilityChecker: StoreSchemaCompatibilityChecking {
    /// Every version of the model the app can migrate from, the current one included. Deferred to call
    /// time (rather than stored models) so constructing this checker doesn't force `LocalDBService.shared`
    /// to initialize at static-`let` evaluation time.
    let knownModels: () -> [NSManagedObjectModel]

    func isCompatible(storeAt url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        ) else {
            return false
        }
        return knownModels().contains { $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) }
    }
}

enum BundledModels {
    /// Every version of the app's Core Data model: all the `.mom` files of the model folder.
    static func all(bundle: Bundle = Bundle(for: LocalDBService.self)) -> [NSManagedObjectModel] {
        guard let folder = bundle.url(forResource: LocalDBService.databaseName, withExtension: "momd"),
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }
        return urls
            .filter { $0.pathExtension == "mom" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { NSManagedObjectModel(contentsOf: $0) }
    }
}

/// Opens a copy of a snapshot with the current model to see that the store can be upgraded.
protocol StoreMigrationVerifying {
    /// Opens the store at `url` with automatic migration, which upgrades it in place, so `url` has to be a
    /// throwaway copy. Throws when the store cannot be opened.
    func verifyStoreCanBeOpened(at url: URL) throws
}

struct CoreDataStoreMigrationVerifier: StoreMigrationVerifying {
    let currentModel: () -> NSManagedObjectModel

    func verifyStoreCanBeOpened(at url: URL) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel())
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentHistoryTrackingKey: true,
            ])
        try coordinator.remove(store)
    }
}
