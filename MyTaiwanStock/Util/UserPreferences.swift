//
//  UserPreferences.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/6/14.
//

import Foundation

enum SyncPreference: String {
    case iCloud
    case local
}

class UserPreferences {
    static let shared = UserPreferences()
    private let syncPreferenceKey = "syncPreference"

    var syncPreference: SyncPreference {
        get {
            let value = UserDefaults.standard.string(forKey: syncPreferenceKey) ?? SyncPreference.local.rawValue
            return SyncPreference(rawValue: value) ?? .local
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: syncPreferenceKey)
        }
    }
}
