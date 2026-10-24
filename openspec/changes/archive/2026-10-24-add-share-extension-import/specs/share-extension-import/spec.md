## Purpose

The share-extension-import capability lets a user send screenshots from the system share sheet into this app's trade screenshot import. It exists so that a broker screenshot can be handed over without first opening the app and searching the photo library, while keeping the stored screenshots short-lived and protected.

## ADDED Requirements

### Requirement: Share sheet accepts images and stores them for later import

The system SHALL provide a share extension that appears in the system share sheet for images only, and SHALL accept at most 10 images per share. The extension SHALL copy each shared image into a new batch folder inside the shared App Group container, in the order the images were shared, SHALL show a confirmation that the images were added, and SHALL then finish. The extension SHALL NOT recognize text, SHALL NOT write any trade record, and SHALL NOT upload any image. The extension SHALL finish only after every image has been copied.

#### Scenario: Images are shared into the app

- **WHEN** the user shares two images to the app from the share sheet
- **THEN** the system SHALL create one batch folder containing both images in the order they were shared
- **AND** the system SHALL show a confirmation that the images were added for import
- **AND** the system SHALL NOT write any trade record

#### Scenario: Sharing a non-image item

- **WHEN** the user opens the share sheet for an item that is not an image
- **THEN** the app SHALL NOT be offered as a share target

#### Scenario: Copying one image fails

- **WHEN** copying or loading one of the shared images fails
- **THEN** the system SHALL remove the incomplete batch
- **AND** the system SHALL show an error message

#### Scenario: Image is still downloading

- **WHEN** a shared image has to be downloaded before it can be copied
- **THEN** the extension SHALL show a loading state until every image has been copied or a failure occurs

#### Scenario: App Group container is unavailable

- **WHEN** the shared App Group container cannot be accessed
- **THEN** the system SHALL show an error message
- **AND** the system SHALL NOT create any batch

### Requirement: Pending images are offered for import when the app becomes active

The system SHALL check for pending batches whenever the app becomes active, when an import flow ends, and when the stock list appears. When a pending batch exists, no import flow is running and no modal screen is shown, the system SHALL ask the user whether to import now or later, stating the number of pending images, and SHALL ask at most once per time the app becomes active. When the user chooses to import now, the system SHALL switch to the stock list tab, SHALL return to the root of the stock list, and SHALL run the existing recognition and confirmation preview flow on the images of the oldest pending batch. When the user chooses later, the system SHALL keep the batch. The system SHALL NOT write any trade record until the user confirms in the preview.

#### Scenario: App is opened with a pending batch

- **WHEN** the app becomes active, one pending batch with three images exists, and nothing else is shown
- **THEN** the system SHALL ask whether to import the three pending screenshots now or later

##### Example: user chooses now from a detail screen

- **GIVEN** the user is on a stock detail screen inside the stock list tab and a pending batch exists
- **WHEN** the user chooses to import now
- **THEN** the system SHALL show the stock list root without animation
- **AND** the system SHALL show the recognition loading screen and then the confirmation preview

#### Scenario: User chooses later

- **WHEN** the user chooses later in the question
- **THEN** the system SHALL keep the batch
- **AND** the system SHALL NOT ask again until the app becomes active again

#### Scenario: Another import flow or modal screen is shown

- **WHEN** the app becomes active while the photo picker, an import flow, or any other modal screen is shown
- **THEN** the system SHALL NOT ask about the pending batch
- **AND** the system SHALL check again when an import flow ends, when the stock list appears, or when the app becomes active again

#### Scenario: Several batches are waiting

- **WHEN** two pending batches exist and the user finishes importing the older one
- **THEN** the system SHALL ask about the next batch after the first flow has ended

#### Scenario: No pending batch

- **WHEN** the app becomes active and no pending batch exists
- **THEN** the app SHALL behave exactly as it does without this capability

### Requirement: Pending images are deleted after recognition or expiry

The system SHALL delete the images of a pending batch once recognition of all its images has produced a result, before the confirmation preview or the message is shown. A result is any of: recognized trades, no recognized trade, or an image loading or recognition error that is reported to the user. The preview SHALL use the recognized trades held in memory. If recognition is interrupted by the system before it produces a result, the system SHALL keep the batch. The system SHALL delete every pending batch that is older than 24 hours and every unfinished temporary batch folder that is older than 1 hour whenever it checks for pending batches.

#### Scenario: Recognition produces trades

- **WHEN** recognition of a batch finishes and trades were recognized
- **THEN** the system SHALL delete the batch folder
- **AND** the system SHALL show the confirmation preview with the recognized trades

#### Scenario: Recognition fails

- **WHEN** loading or recognizing an image of a batch fails with an error
- **THEN** the system SHALL delete the batch folder
- **AND** the system SHALL show the error message

#### Scenario: Recognition is interrupted

- **WHEN** the app goes to the background before recognition of a batch has produced a result
- **THEN** the batch SHALL still exist and SHALL be offered again the next time the app becomes active

#### Scenario: Batch is too old

- **WHEN** the system checks for pending batches and a batch was created more than 24 hours ago
- **THEN** the system SHALL delete that batch without importing it

#### Scenario: Temporary folder is left behind

- **WHEN** the system checks for pending batches and an unfinished temporary batch folder is older than 1 hour
- **THEN** the system SHALL delete that folder

### Requirement: Pending images stay on the device and are protected

The system SHALL keep pending images only inside the shared App Group container on the device. The system SHALL NOT upload pending images or their recognized text to any server, and SHALL exclude the pending import folder from iCloud and computer backups and from iCloud backup and Firebase synchronization of the app. The system SHALL protect pending image files so that they cannot be read while the device is locked, SHALL NOT create thumbnails of them, and SHALL NOT write image content or recognized text to logs. When a pending image cannot be read because the device is locked, the system SHALL treat it as temporarily unavailable and SHALL NOT delete it.

#### Scenario: Backup and sync run while a batch is pending

- **WHEN** a device backup, iCloud backup or Firebase synchronization runs while a pending batch exists
- **THEN** the pending batch SHALL NOT be included

#### Scenario: Device is locked

- **WHEN** the system tries to read a pending image while the device is locked
- **THEN** the system SHALL treat the image as temporarily unavailable
- **AND** the system SHALL NOT delete the batch
