## ADDED Requirements

### Requirement: Restore accepts snapshots from earlier model versions

When the system checks an iCloud snapshot before restoring it, the system SHALL treat the snapshot as compatible when its Core Data model matches any version of the app's model that is bundled with the app, and SHALL treat a snapshot whose model matches no bundled version as incompatible and SHALL NOT restore it.

#### Scenario: Snapshot from the previous model version

- **GIVEN** an iCloud snapshot created by an app version whose model has no fee and tax values
- **WHEN** the system checks the snapshot
- **THEN** the snapshot SHALL be reported as compatible

#### Scenario: Snapshot from an unknown model

- **WHEN** the snapshot's model matches no bundled model version
- **THEN** the system SHALL report the snapshot as incompatible
- **AND** the system SHALL NOT replace the current database

### Requirement: Verify the snapshot can be migrated before replacing the database

Before the system replaces the current database with a compatible snapshot, the system SHALL copy the snapshot to a temporary location and open the copy with the current model and automatic migration. The system SHALL replace the current database only when the copy opens successfully, SHALL replace it with a copy of the same snapshot content that was verified, without reading the snapshot from iCloud again, and SHALL upgrade the restored database to the current model version when it is opened. The system SHALL remove its temporary copies whether the restore succeeds or fails. When the copy cannot be opened, the system SHALL report an error, SHALL leave the current database and its files unchanged, and SHALL remove the temporary copy.

#### Scenario: Restore of an earlier version snapshot

- **GIVEN** an iCloud snapshot created by an app version whose model has no fee and tax values
- **WHEN** the user restores it in the current app version
- **THEN** the restore SHALL succeed
- **AND** every record SHALL be present with unknown fee and tax
- **AND** no temporary copy of the snapshot SHALL remain

#### Scenario: Snapshot that cannot be migrated

- **WHEN** the temporary copy cannot be opened with the current model
- **THEN** the system SHALL show an error
- **AND** the current database SHALL be unchanged and the app SHALL keep working with it
