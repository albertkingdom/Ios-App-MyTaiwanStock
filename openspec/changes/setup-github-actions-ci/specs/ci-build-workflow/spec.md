## ADDED Requirements

### Requirement: Automatic build and test on pull requests
The system SHALL run a GitHub Actions workflow that builds the `MyTaiwanStock` app target, the `StockWidgetExtension` target, and the `LiveActivityExtension` target, and executes the `MyTaiwanStockTests` unit test target, whenever a pull request targeting the `mvvm` branch is opened or updated.

#### Scenario: PR opened against mvvm triggers workflow
- **WHEN** a contributor opens a pull request with `mvvm` as the base branch
- **THEN** GitHub Actions SHALL start a workflow run named `CI` for that pull request

#### Scenario: New commits pushed to an open PR re-trigger the workflow
- **WHEN** a contributor pushes new commits to the source branch of an already-open pull request targeting `mvvm`
- **THEN** GitHub Actions SHALL start a new `CI` workflow run reflecting the latest commit

### Requirement: Automatic build and test on push to default branch
The system SHALL run the same build-and-test workflow whenever commits are pushed directly to the `mvvm` branch.

#### Scenario: Push to mvvm triggers workflow
- **WHEN** a commit is pushed directly to the `mvvm` branch
- **THEN** GitHub Actions SHALL start a `CI` workflow run for that push

### Requirement: Build without code signing
The system SHALL build all app and extension targets for the iOS Simulator destination with code signing disabled, so the workflow does not require any Apple Developer signing credentials to succeed.

#### Scenario: Build succeeds without imported certificates
- **WHEN** the `CI` workflow builds `MyTaiwanStock`, `StockWidgetExtension`, and `LiveActivityExtension` on a runner with no code signing certificate or provisioning profile installed
- **THEN** each build step SHALL complete successfully because code signing is disabled for the build

### Requirement: Unit test execution and reporting
The system SHALL execute the `MyTaiwanStockTests` target via `xcodebuild test` against an iOS Simulator destination as part of the workflow.

#### Scenario: All unit tests pass
- **WHEN** every test case in `MyTaiwanStockTests` passes
- **THEN** the `CI` workflow run SHALL be marked as successful (green check) on the associated commit and pull request

#### Scenario: A unit test fails
- **WHEN** at least one test case in `MyTaiwanStockTests` fails or crashes
- **THEN** the `CI` workflow run SHALL be marked as failed, and the failing test case name SHALL appear in the workflow run log

### Requirement: Build failure is surfaced, not silenced
The system SHALL mark the workflow run as failed if Swift Package Manager dependency resolution fails or if any of the three non-test targets fail to build, without proceeding to later steps that depend on a successful build.

#### Scenario: Dependency resolution fails
- **WHEN** `xcodebuild -resolvePackageDependencies` fails (e.g., a package source is unreachable)
- **THEN** the workflow SHALL stop at that step, mark the run as failed, and SHALL NOT attempt subsequent build or test steps

#### Scenario: A target fails to compile
- **WHEN** a build step for `MyTaiwanStock`, `StockWidgetExtension`, or `LiveActivityExtension` fails due to a compilation error
- **THEN** the workflow run SHALL be marked as failed and the `xcodebuild` error output SHALL be present in the run log
