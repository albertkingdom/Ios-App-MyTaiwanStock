//
//  ICloudAvailabilityChecking.swift
//  MyTaiwanStock
//

import Foundation

protocol ICloudAvailabilityChecking {
    func isICloudAvailable() -> Bool
}

struct DefaultICloudAvailabilityChecker: ICloudAvailabilityChecking {
    func isICloudAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
