## MODIFIED Requirements

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
- **AND** the device has an active iCloud account
- **THEN** the system SHALL perform a backup immediately regardless of the throttle window
- **AND** SHALL report success to the user only after the snapshot write completes

#### Scenario: Manual backup fails when iCloud is unavailable
- **WHEN** the user taps "Backup Now" in Settings
- **AND** the device has no active iCloud account (`FileManager.default.ubiquityIdentityToken` is `nil`)
- **THEN** the system SHALL NOT perform a backup
- **AND** SHALL surface a failure to the caller (not a silent no-op)
- **AND** the Settings screen SHALL display an error message to the user instead of a success message

### Requirement: Independent optional toggles with combined-off warning

Firebase login and iCloud backup SHALL remain independently optional and SHALL NOT be coupled to each other. The Settings screen SHALL display explanatory text for each toggle and SHALL display a warning (not a block) when both are disabled or otherwise not actually protecting the user's data.

#### Scenario: Explanatory text shown per toggle
- **WHEN** the user views the Settings screen
- **THEN** the system SHALL display text next to the iCloud backup toggle clarifying it performs periodic local-device backup, not real-time sync
- **AND** SHALL display text next to the Firebase login section clarifying it enables cross-device and cross-platform (including Android) sync

#### Scenario: Both mechanisms disabled
- **WHEN** the user has iCloud backup disabled
- **AND** the user has no active Firebase login
- **THEN** the system SHALL display a warning stating that data will be unrecoverable if the app is deleted or the device is replaced
- **AND** SHALL NOT block the user from continuing to use the app

#### Scenario: iCloud backup toggle enabled but device not signed into iCloud
- **WHEN** the user has enabled the iCloud backup toggle in Settings
- **AND** the device has no active iCloud account (`FileManager.default.ubiquityIdentityToken` is `nil`)
- **AND** the user has no active Firebase login
- **THEN** the system SHALL treat the data-protection state as equivalent to the toggle being disabled
- **AND** SHALL display the same unrecoverable-data-loss warning as when the toggle is off
- **AND** SHALL additionally state that iCloud backup will not run until the device is signed into iCloud
