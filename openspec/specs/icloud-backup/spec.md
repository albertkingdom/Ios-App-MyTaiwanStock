# icloud-backup Specification

## Purpose

TBD - created by archiving change 'rework-icloud-sync-to-backup'. Update Purpose after archive.

## Requirements

### Requirement: Periodic iCloud snapshot backup

The system SHALL back up the local Core Data store to the iCloud Drive ubiquity container as a periodic snapshot instead of mirroring every write in real time via CloudKit. The system SHALL NOT use `NSPersistentCloudKitContainer` for continuous record-level sync.

#### Scenario: Backup triggered on app entering background
- **WHEN** the app enters the background
- **AND** local data has changed since the last successful backup
- **AND** at least 1 hour has elapsed since the last successful backup
- **THEN** the system SHALL copy the current Core Data sqlite store to the iCloud Drive ubiquity container within the background execution window
- **AND** the system SHALL update the last-backup timestamp on success

#### Scenario: Backup skipped when throttle window not elapsed
- **WHEN** the app enters the background
- **AND** less than 1 hour has elapsed since the last successful backup
- **THEN** the system SHALL NOT perform a backup

##### Example: throttle boundary
| Time since last backup | Data changed | Backup performed |
| --- | --- | --- |
| 59 minutes | yes | no |
| 60 minutes | yes | yes |
| 61 minutes | no | no |

#### Scenario: Backup check on app launch or foreground
- **WHEN** the app launches or returns to the foreground
- **THEN** the system SHALL evaluate the same throttle and change-detection rules as the background trigger
- **AND** SHALL perform a backup if the conditions are met

#### Scenario: Manual backup from Settings
- **WHEN** the user taps "Backup Now" in Settings
- **THEN** the system SHALL perform a backup immediately regardless of the throttle window


<!-- @trace
source: rework-icloud-sync-to-backup
updated: 2026-08-02
code:
  - MyTaiwanStock/Util/URL+Extension.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - README.md
  - MyTaiwanStock/Util/BackupDestination.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - CLAUDE.md
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/BackupDestinationTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStock/Util/SceneICloudCoordinator.swift
  - MyTaiwanStock/Util/ICloudAvailabilityChecking.swift
  - MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStockTests/LocalDBServiceCrashFixesTests.swift
  - MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/View Controller/AccountViewController.swift
  - MyTaiwanStockTests/SceneICloudCoordinatorTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStock/Util/Clock.swift
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
-->

---
### Requirement: Graceful degradation when iCloud is unavailable

The system SHALL NOT crash when iCloud is unavailable, when the app group container cannot be resolved for the shared local store, or when Core Data save operations fail.

#### Scenario: iCloud not signed in at OS level
- **WHEN** the device has no active iCloud account (`FileManager.default.ubiquityIdentityToken` is `nil`)
- **THEN** the system SHALL disable backup functionality
- **AND** SHALL continue normal local Core Data operation without crashing

#### Scenario: Core Data save failure
- **WHEN** `NSManagedObjectContext.save()` throws an error
- **THEN** the system SHALL log the error and post a `.dataSaveDidFail` notification
- **AND** SHALL NOT terminate the app via `fatalError`

#### Scenario: Known CloudKit-related persistent store load errors
- **WHEN** loading the persistent store surfaces a `CKError` with code `.notAuthenticated`, `.networkUnavailable`, `.serverRecordChanged`, `.zoneNotFound`, `.partialFailure`, or `.quotaExceeded`
- **THEN** the system SHALL log the specific error classification
- **AND** SHALL NOT terminate the app via `fatalError`

#### Scenario: App group container unavailable
- **WHEN** `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` for the app's shared container
- **THEN** the system SHALL treat this as a configuration error and terminate with a diagnostic message identifying it as an entitlement misconfiguration


<!-- @trace
source: rework-icloud-sync-to-backup
updated: 2026-08-02
code:
  - MyTaiwanStock/Util/URL+Extension.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - README.md
  - MyTaiwanStock/Util/BackupDestination.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - CLAUDE.md
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/BackupDestinationTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStock/Util/SceneICloudCoordinator.swift
  - MyTaiwanStock/Util/ICloudAvailabilityChecking.swift
  - MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStockTests/LocalDBServiceCrashFixesTests.swift
  - MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/View Controller/AccountViewController.swift
  - MyTaiwanStockTests/SceneICloudCoordinatorTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStock/Util/Clock.swift
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
-->

---
### Requirement: Restore scoped to users without a Firebase login

The system SHALL offer iCloud snapshot restore only to users who have never logged into a Firebase account on the current local store. Once a user is logged into Firebase, Firestore SHALL be the sole authoritative source for restore, and the system SHALL NOT read from or merge iCloud snapshot content.

#### Scenario: Restore offered for local-only user
- **WHEN** the app launches
- **AND** the local Core Data store contains no data
- **AND** the user has no active Firebase login
- **AND** an iCloud backup snapshot exists in the ubiquity container
- **THEN** the system SHALL prompt the user to restore from the iCloud snapshot

#### Scenario: Restore not offered for logged-in Firebase user
- **WHEN** the app launches
- **AND** the user has an active Firebase login
- **THEN** the system SHALL NOT prompt for or perform iCloud snapshot restore
- **AND** SHALL rely on the existing Firestore-based data retrieval instead


<!-- @trace
source: rework-icloud-sync-to-backup
updated: 2026-08-02
code:
  - MyTaiwanStock/Util/URL+Extension.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - README.md
  - MyTaiwanStock/Util/BackupDestination.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - CLAUDE.md
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/BackupDestinationTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStock/Util/SceneICloudCoordinator.swift
  - MyTaiwanStock/Util/ICloudAvailabilityChecking.swift
  - MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStockTests/LocalDBServiceCrashFixesTests.swift
  - MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/View Controller/AccountViewController.swift
  - MyTaiwanStockTests/SceneICloudCoordinatorTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStock/Util/Clock.swift
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
-->

---
### Requirement: Independent optional toggles with combined-off warning

Firebase login and iCloud backup SHALL remain independently optional and SHALL NOT be coupled to each other. The Settings screen SHALL display explanatory text for each toggle and SHALL display a warning (not a block) when both are disabled.

#### Scenario: Explanatory text shown per toggle
- **WHEN** the user views the Settings screen
- **THEN** the system SHALL display text next to the iCloud backup toggle clarifying it performs periodic local-device backup, not real-time sync
- **AND** SHALL display text next to the Firebase login section clarifying it enables cross-device and cross-platform (including Android) sync

#### Scenario: Both mechanisms disabled
- **WHEN** the user has iCloud backup disabled
- **AND** the user has no active Firebase login
- **THEN** the system SHALL display a warning stating that data will be unrecoverable if the app is deleted or the device is replaced
- **AND** SHALL NOT block the user from continuing to use the app

<!-- @trace
source: rework-icloud-sync-to-backup
updated: 2026-08-02
code:
  - MyTaiwanStock/Util/URL+Extension.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - README.md
  - MyTaiwanStock/Util/BackupDestination.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - CLAUDE.md
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/BackupDestinationTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStock/Util/SceneICloudCoordinator.swift
  - MyTaiwanStock/Util/ICloudAvailabilityChecking.swift
  - MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStockTests/LocalDBServiceCrashFixesTests.swift
  - MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/View Controller/AccountViewController.swift
  - MyTaiwanStockTests/SceneICloudCoordinatorTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStock/Util/Clock.swift
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
-->