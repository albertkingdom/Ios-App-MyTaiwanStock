## MODIFIED Requirements

### Requirement: Recognize trades from screenshots on device

The system SHALL let the user pick one or more screenshots with the system photo picker, or receive the images of a pending batch shared through the share extension, and SHALL recognize the text in each image on the device using Vision text recognition with Traditional Chinese enabled and language correction disabled, one image at a time. The system SHALL NOT upload the screenshots or the recognized text to any server.

#### Scenario: Multiple screenshots are merged into one preview

- **WHEN** the user selects two screenshots and both contain trade rows
- **THEN** the system SHALL recognize each image and present all recognized trades together in a single preview list

#### Scenario: Screenshots from a pending batch are recognized the same way

- **WHEN** the images of a pending batch shared through the share extension contain trade rows
- **THEN** the system SHALL recognize each image with the same settings as picker images
- **AND** the system SHALL present all recognized trades together in a single preview list

#### Scenario: Screenshot without trades

- **WHEN** the recognized text of every selected screenshot contains no trade row
- **THEN** the system SHALL show a message that no importable trade was found
- **AND** the system SHALL NOT write any record

#### Scenario: Image cannot be loaded or recognized

- **WHEN** a selected image cannot be loaded or the recognition request fails
- **THEN** the system SHALL show an error message
- **AND** the system SHALL NOT write any record
