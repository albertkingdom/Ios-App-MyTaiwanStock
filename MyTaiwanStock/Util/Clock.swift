//
//  Clock.swift
//  MyTaiwanStock
//

import Foundation

/// Named `BackupClock` (not `Clock`) deliberately: Swift's standard library already
/// defines `protocol Clock` (`var now: Instant`, from Swift Concurrency) which is visible
/// in every file without any extra import. Reusing that name here would shadow/ambiguate
/// against the stdlib protocol at every call site (`clock.now()` would resolve against the
/// stdlib's `Instant`-returning `now` property instead of this `Date`-returning method).
protocol BackupClock {
    func now() -> Date
}

struct SystemBackupClock: BackupClock {
    func now() -> Date {
        Date()
    }
}
