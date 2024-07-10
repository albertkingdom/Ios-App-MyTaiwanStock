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
            let value = UserDefaults.standard.string(forKey: syncPreferenceKey) ?? SyncPreference.iCloud.rawValue
            print("sync value \(value)")
            return SyncPreference(rawValue: value) ?? .iCloud
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: syncPreferenceKey)
            print("sync newValue \(newValue)")
        }
    }
}
