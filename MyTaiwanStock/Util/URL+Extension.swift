//
//  URL+Extension.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/6/15.
//

import Foundation

extension URL {
    /// Returns `nil` when the app group container cannot be resolved (e.g. missing
    /// `com.apple.security.application-groups` entitlement). Callers that require the
    /// store to exist should treat `nil` as a configuration error.
    static func storeURL(for appGroup: String, databaseName: String) -> URL? {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            print("URL.storeURL: app group container '\(appGroup)' could not be resolved. Check the application-groups entitlement.")
            return nil
        }
        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}
