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
    /// Deferred to call time (rather than a stored `NSManagedObjectModel`) so constructing
    /// this checker doesn't force `LocalDBService.shared` to initialize at static-`let`
    /// evaluation time.
    let managedObjectModel: () -> NSManagedObjectModel

    func isCompatible(storeAt url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        ) else {
            return false
        }
        return managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }
}
