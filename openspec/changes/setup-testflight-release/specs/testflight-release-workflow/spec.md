## ADDED Requirements

### Requirement: Manual TestFlight release trigger
The system SHALL provide a GitHub Actions workflow that packages and uploads a new TestFlight build without requiring the operator to run any local commands, triggerable either manually (`workflow_dispatch`) or automatically by pushing a git tag matching `v*`.

#### Scenario: Operator triggers a release from GitHub Actions
- **WHEN** a repository collaborator manually triggers the `TestFlight Release` workflow from the GitHub Actions UI, selecting a branch
- **THEN** GitHub Actions SHALL start a workflow run named `TestFlight Release` that checks out the selected branch/commit

#### Scenario: Pushing a version tag triggers a release automatically
- **WHEN** a collaborator pushes a git tag matching `v*` (e.g. `v1.0.1`) to the repository
- **THEN** GitHub Actions SHALL automatically start a workflow run named `TestFlight Release` that checks out the commit the tag points to, without any manual trigger

#### Scenario: Pushing to a branch does not trigger a release
- **WHEN** a collaborator pushes commits to any branch (including `mvvm` or `release`) without pushing a matching `v*` tag
- **THEN** the `TestFlight Release` workflow SHALL NOT be triggered

### Requirement: Tag-triggered releases must originate from the release branch
When the workflow is triggered by a `v*` tag push, the system SHALL verify that the tagged commit exists in the history of the `release` branch before performing any signing, build, or upload step. This restriction SHALL NOT apply to manually-triggered (`workflow_dispatch`) runs.

#### Scenario: Tag points to a commit on the release branch
- **WHEN** a `v*` tag is pushed and the tagged commit is an ancestor of (or equal to) `origin/release`
- **THEN** the workflow SHALL proceed to the signing, build, and upload steps

#### Scenario: Tag points to a commit not on the release branch
- **WHEN** a `v*` tag is pushed (e.g. from `mvvm` or a feature branch) and the tagged commit is not in the history of `origin/release`
- **THEN** the workflow SHALL fail immediately with a message identifying that the tag does not originate from the `release` branch, and SHALL NOT execute any signing, build, or upload step

#### Scenario: Manual dispatch bypasses the release-branch restriction
- **WHEN** the workflow is triggered via `workflow_dispatch` on any branch
- **THEN** the release-branch verification step SHALL be skipped and the workflow SHALL proceed normally

### Requirement: Signing without local Apple ID interaction
The system SHALL sign the `MyTaiwanStock`, `StockWidgetExtension`, and `LiveActivityExtension` targets for App Store distribution using fastlane match, retrieving certificates and provisioning profiles from the existing `github.com/albertkingdom/ios-signing` private repository, without any interactive Apple ID prompt.

#### Scenario: Match retrieves an existing App Store distribution certificate
- **WHEN** the workflow runs `fastlane match appstore` and a valid, unexpired App Store distribution certificate already exists in the `ios-signing` repository for team `UZ2Z639589`
- **THEN** match SHALL reuse that certificate rather than creating a new one, and SHALL install it into the runner's keychain non-interactively

#### Scenario: Match creates a missing provisioning profile for MyTaiwanStock
- **WHEN** the `ios-signing` repository does not yet contain a provisioning profile for a given bundle id (`com.a2006mike.MyTaiwanStock`, `com.a2006mike.MyTaiwanStock.StockWidget`, or `com.a2006mike.MyTaiwanStock.LiveActivity`)
- **THEN** match SHALL create the missing App Store provisioning profile using the App Store Connect API Key credentials and store it back into the `ios-signing` repository

### Requirement: App Store Connect authentication via API key only
The system SHALL authenticate to App Store Connect using an API Key (Key ID, Issuer ID, and .p8 private key content) supplied via GitHub Secrets, and SHALL NOT use an Apple ID username/password or interactive two-factor authentication at any point in the workflow.

#### Scenario: Workflow authenticates without 2FA prompt
- **WHEN** the workflow needs to call App Store Connect for match, build number lookup, or the TestFlight upload
- **THEN** it SHALL do so using the API Key loaded from `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, and `APP_STORE_CONNECT_API_KEY_CONTENT`, and the workflow SHALL NOT prompt for or require a two-factor authentication code

### Requirement: Build number auto-increment without version collision
The system SHALL determine the next build number by querying the latest TestFlight build number for the app from App Store Connect and incrementing it by one, rather than relying solely on the build number already committed in `project.pbxproj`.

#### Scenario: Existing builds present on App Store Connect
- **WHEN** App Store Connect already has at least one processed build for `com.a2006mike.MyTaiwanStock`
- **THEN** the workflow SHALL set `CURRENT_PROJECT_VERSION` for the build to (latest TestFlight build number + 1) before archiving

#### Scenario: No prior builds exist on App Store Connect
- **WHEN** the latest-build-number lookup finds no existing build for the app (first-ever upload)
- **THEN** the workflow SHALL fall back to the `CURRENT_PROJECT_VERSION` value already present in `project.pbxproj` as the starting build number, rather than failing the lane

#### Scenario: Build number change is not committed to git
- **WHEN** the workflow increments the build number for a release
- **THEN** this change SHALL apply only to the checked-out working copy used for that workflow run, and SHALL NOT be committed or pushed back to any branch in the repository

### Requirement: Archive, export, and upload to TestFlight
The system SHALL archive the `MyTaiwanStock` scheme using the App Store distribution method, export a signed IPA, and upload it to TestFlight without waiting for App Store Connect build processing to complete.

#### Scenario: Successful end-to-end release
- **WHEN** signing, build number increment, archive, and export all succeed
- **THEN** the workflow SHALL upload the resulting IPA to TestFlight via the App Store Connect API and SHALL mark the workflow run as successful once the upload call completes, without blocking on build processing status

### Requirement: Failures are surfaced without partial-success states
The system SHALL mark the workflow run as failed if any step in the release lane (API key setup, match, build number lookup, archive, or upload) fails, and SHALL NOT proceed to later steps after a failure.

#### Scenario: Match fails due to invalid credentials
- **WHEN** `MATCH_PASSWORD` or the `ios-signing` repository access credential is missing or incorrect
- **THEN** the match step SHALL fail with an identifiable error in the workflow log, the workflow run SHALL be marked as failed, and the workflow SHALL NOT proceed to the archive step

#### Scenario: Upload to TestFlight fails after a successful archive
- **WHEN** archiving and export succeed but `upload_to_testflight` fails (e.g., network error or App Store Connect rejection)
- **THEN** the workflow run SHALL be marked as failed, and the failure SHALL be visible in the workflow log rather than being silently swallowed or reported as success
