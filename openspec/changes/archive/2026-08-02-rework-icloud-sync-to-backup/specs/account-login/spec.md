## ADDED Requirements

### Requirement: Local data import confirmation on Firebase login

The system SHALL NOT automatically merge existing local Core Data content into Firestore when a user logs into a Firebase account. When local data exists at login time, the system SHALL prompt the user for explicit confirmation before uploading any local data to Firestore.

#### Scenario: Local data present at login
- **WHEN** the user completes Firebase login on the Account screen
- **AND** the local Core Data store contains at least one `List`
- **THEN** the system SHALL present a confirmation dialog asking whether to import local data into the logged-in account
- **AND** SHALL only call the existing upload functions (e.g. `uploadListToOnlineDB`) if the user confirms

#### Scenario: User declines import
- **WHEN** the user declines the import confirmation dialog
- **THEN** the system SHALL retain the local data unchanged
- **AND** SHALL NOT upload it to Firestore

#### Scenario: No local data present at login
- **WHEN** the user completes Firebase login on the Account screen
- **AND** the local Core Data store contains no `List`
- **THEN** the system SHALL skip the import confirmation dialog

### Requirement: Firestore as authoritative restore source after login

Once a user is logged into Firebase, the system SHALL treat Firestore as the authoritative source for restoring Lists, StockNo entries, and history records, and SHALL NOT read from iCloud backup snapshots for restore purposes.

#### Scenario: Data retrieval after login
- **WHEN** a user with an active Firebase login opens the app on any device
- **THEN** the system SHALL retrieve Lists and history from Firestore via the existing `getAllListAndStocksFromOnlineDBAndSaveToLocal` and `getAllHistoryFromOnlineDBAndSaveToLocal` mechanisms
- **AND** SHALL NOT consult any iCloud backup snapshot as part of this retrieval
