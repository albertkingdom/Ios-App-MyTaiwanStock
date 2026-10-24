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
- **AND** the device has an active iCloud account
- **THEN** the system SHALL perform a backup immediately regardless of the throttle window
- **AND** SHALL report success to the user only after the snapshot write completes

#### Scenario: Manual backup fails when iCloud is unavailable
- **WHEN** the user taps "Backup Now" in Settings
- **AND** the device has no active iCloud account (`FileManager.default.ubiquityIdentityToken` is `nil`)
- **THEN** the system SHALL NOT perform a backup
- **AND** SHALL surface a failure to the caller (not a silent no-op)
- **AND** the Settings screen SHALL display an error message to the user instead of a success message


<!-- @trace
source: fix-icloud-backup-not-signed-in
updated: 2026-08-02
code:
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/SettingViewControllerTests.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - README.md
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

<!-- @trace
source: fix-icloud-backup-not-signed-in
updated: 2026-08-02
code:
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/SettingViewControllerTests.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - README.md
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
-->

---
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


<!-- @trace
source: store-fee-and-tax
updated: 2026-10-24
code:
  - MyTaiwanStockTests/Screens/StockList/ListNameTests.swift
  - MyTaiwanStock/Screens/Dividend/View/DividendDetailTableViewCell.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStockTests/TradeCost/OverViewCalculatorTests.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Screens/Onboarding/ViewController/WalkthroughViewController.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/AddStockCellViewModel.swift
  - MyTaiwanStock/Screens/TradeImport/Services/StockNameResolver.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Screens/StockList/Model/ListStruct.swift
  - MyTaiwanStock/Screens/News/ViewController/NewsListViewController.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/View Controller/NewsListViewController.swift
  - MyTaiwanStock/Model/MyStockList.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/View Controller/StockViewController.swift
  - MyTaiwanStock/View Controller/View Model/AddDividendViewModel.swift
  - MyTaiwanStock/View/ViewController+extension.swift
  - MyTaiwanStock/Screens/Chat/Model/Channel.swift
  - MyTaiwanStock/Model/CoreData/StockNoStruct.swift
  - MyTaiwanStock/Model/FeeType.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/AddStockNoViewModel.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticStockTableViewCell.swift
  - MyTaiwanStock/Screens/StockList/Model/StockNoStruct.swift
  - MyTaiwanStock/AppCoordinator.swift
  - MyTaiwanStock/Model/Fee.swift
  - MyTaiwanStock/Screens/TradeEntry/ViewController/AddHistoryViewController.swift
  - MyTaiwanStock/Screens/TradeEntry/ViewController/MemoViewController.swift
  - MyTaiwanStock/View/NewsListCellViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticTableViewCell.swift
  - MyTaiwanStock/View Controller/AddDividendViewController.swift
  - MyTaiwanStock/StockList/View/StockTableViewCell.swift
  - MyTaiwanStock/Model/StockInfo.swift
  - MyTaiwanStock/Screens/TradeImport/ViewModel/TradeImportViewModel.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - Localizable.xcstrings
  - MyTaiwanStock/Screens/Chat/ViewModel/ChatViewModel.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/View/AddStockCellViewModel.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Screens/Dividend/ViewModel/AddDividendViewModel.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportViewModelTests.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticStockTableViewCell.xib
  - MyTaiwanStock/Screens/Chat/Model/Message.swift
  - MyTaiwanStock/Screens/StockList/ViewController/AddListViewController.swift
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock/Screens/StockDetail/View/NewHistoryTableViewCell.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewModelTests.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Screens/StockList/View/StockTableViewCell.swift
  - MyTaiwanStockTests/Screens/StockList/DuplicateStockNoTests.swift
  - MyTaiwanStock/Screens/Chat/ViewController/ChatViewController.swift
  - MyTaiwanStock/Screens/StockDetail/ViewModel/StockDetailViewModel.swift
  - MyTaiwanStock/View/AddStockTableViewCell.swift
  - MyTaiwanStock/View/HistoryCellModel.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStock/Screens/TradeEntry/ViewModel/AddHistoryViewModel.swift
  - MyTaiwanStock/Util/FeeCalculator.swift
  - MyTaiwanStock/Screens/Statistics/ViewModel/StatisticViewModel.swift
  - MyTaiwanStock/View/DividendDetailTableViewCell.xib
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/View Controller/View Model/AddHistoryViewModel.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Shared/Model/StockListEntry.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticDividendTableViewCell.swift
  - MyTaiwanStockTests/TradeCost/FeeCalculatorTests.swift
  - MyTaiwanStock/Shared/Model/HistoryOnline.swift
  - MyTaiwanStock/Shared/Model/MyTaiwanStock.xcdatamodeld/.xccurrentversion
  - MyTaiwanStockTests/Screens/TradeImport/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Screens/News/ViewController/webViewController.swift
  - MyTaiwanStock/View/StatisticStockTableViewCell.xib
  - MyTaiwanStock/Model/Channel.swift
  - MyTaiwanStock/App/AppDelegate.swift
  - MyTaiwanStockTests/TradeCost/FeeTaxFieldsTests.swift
  - MyTaiwanStock/Model/Message.swift
  - MyTaiwanStock/Screens/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/NewHistoryTableViewCell.swift
  - MyTaiwanStock/Screens/StockDetail/Model/StockInfo.swift
  - MyTaiwanStock/Screens/Dividend/ViewController/AddDividendViewController.swift
  - MyTaiwanStock/Screens/Statistics/ViewController/StatisticViewController.swift
  - MyTaiwanStock/View Controller/AddStockNoViewController.swift
  - MyTaiwanStock/App/SceneDelegate.swift
  - MyTaiwanStock/View Controller/AddHistoryViewController.swift
  - MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock 2.xcdatamodel/contents
  - MyTaiwanStock/Screens/News/View/NewsListTableViewCell2.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Repository/NetworkService.swift
  - MyTaiwanStock/Screens/TradeImport/Services/TradeTextRecognizer.swift
  - MyTaiwanStock/View Controller/WalkthroughViewController.swift
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
  - MyTaiwanStock/Model/StockStatistic.swift
  - MyTaiwanStock/TradeCost/Services/OverViewCalculator.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStock/Screens/News/ViewModel/NewsListCellViewModel.swift
  - MyTaiwanStock/Screens/Settings/ViewController/SettingViewController.swift
  - MyTaiwanStock/View Controller/View Model/AddListViewModel.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/AddListViewModel.swift
  - MyTaiwanStock/Screens/StockList/Model/FavList.swift
  - MyTaiwanStock/Screens/TradeImport/Coordinator/TradeImportFlow.swift
  - MyTaiwanStock/View/DividendDetailTableViewCell.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/View/StatisticDividendTableViewCell.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStockTests/Screens/StockList/StockListRefresherTests.swift
  - MyTaiwanStock/SharedUI/FontManager.swift
  - MyTaiwanStock/Screens/TradeImport/Services/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/testOverViewCalculator.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeScreenshotParserTests.swift
  - MyTaiwanStock/Screens/StockList/ViewController/AddStockNoViewController.swift
  - MyTaiwanStock/View Controller/AddListViewController.swift
  - MyTaiwanStock/App/DependencyContainer.swift
  - MyTaiwanStock/App/AppCoordinator.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticDividendTableViewCell.xib
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/Screens/StockList/AddStockNoViewModelTests.swift
  - MyTaiwanStock/View Controller/webViewController.swift
  - MyTaiwanStock/View Controller/AccountViewController.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/TradeCost/Model/FeeTaxFields.swift
  - MyTaiwanStock/TradeCost/Services/FeeCalculator.swift
  - MyTaiwanStock/View/StatisticTableViewCell.swift
  - MyTaiwanStock/Model/OnlineDB/FavList.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/SharedUI/FloatingButtonManagerTests.swift
  - MyTaiwanStock/View Controller/DividendDetailViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportFlowTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/Screens/StockList/StockListCoordinatorImportTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/EditFeeViewController.swift
  - MyTaiwanStock/View Controller/CustomTabBarViewController.swift
  - MyTaiwanStock/Screens/TradeImport/ViewController/TradeEditViewController.swift
  - MyTaiwanStock/Model/Sender.swift
  - MyTaiwanStockTests/HistoryOnlineTests.swift
  - MyTaiwanStockTests/FeeCalculatorTests.swift
  - MyTaiwanStock/App/CustomTabBarViewController.swift
  - MyTaiwanStock/Screens/TradeImport/Services/TradeImageSource.swift
  - MyTaiwanStock/StockList/TradeImageSource.swift
  - MyTaiwanStock/View/StatisticStockTableViewCell.swift
  - MyTaiwanStockTests/BackupDestinationTests.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/StockCellViewModel.swift
  - MyTaiwanStock/SharedUI/ViewController+extension.swift
  - MyTaiwanStock/Screens/News/Model/NewsAPI.swift
  - docs/architecture/source-layout.md
  - MyTaiwanStock/Screens/TradeImport/Services/TradeScreenshotParser.swift
  - MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock.xcdatamodel/contents
  - MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - MyTaiwanStock/Model/OnlineDB/HistoryOnline.swift
  - MyTaiwanStockTests/Screens/TradeImport/DefaultTradeImportStoreTests.swift
  - MyTaiwanStockTests/Screens/StockList/TestStockListViewModel.swift
  - MyTaiwanStockTests/DuplicateStockNoTests.swift
  - MyTaiwanStock/Screens/TradeImport/Model/TradeImportModels.swift
  - MyTaiwanStock/View Controller/View Model/StatisticViewModel.swift
  - MyTaiwanStock/SharedUI/FloatingButton.swift
  - MyTaiwanStock/Screens/Statistics/Model/StockStatistic.swift
  - MyTaiwanStockTests/FeeSettingsTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Screens/StockList/View/AddStockTableViewCell.swift
  - MyTaiwanStock/Util/BackupDestination.swift
  - MyTaiwanStock/View Controller/MemoViewController.swift
  - MyTaiwanStockTests/Screens/StockDetail/StockDetailOverviewTests.swift
  - MyTaiwanStockTests/StockListCoordinatorImportTests.swift
  - MyTaiwanStockTests/TradeImportFlowTests.swift
  - MyTaiwanStock/View Controller/ChatViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/StockNameResolverTests.swift
  - MyTaiwanStock/Screens/Dividend/ViewController/DividendDetailViewController.swift
  - MyTaiwanStock/Screens/StockDetail/View/NewHistoryTableViewCell.xib
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/Shared/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock 2.xcdatamodel/contents
  - MyTaiwanStock/Screens/News/ViewModel/NewsListViewModel.swift
  - MyTaiwanStock/UnreadManager.swift
  - MyTaiwanStock/Model/History.swift
  - MyTaiwanStock/Screens/StockList/Model/MyStockList.swift
  - MyTaiwanStockTests/TradeCost/FeeSettingsTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/View/NewHistoryTableViewCell.xib
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStock/Model/CoreData/ListStruct.swift
  - MyTaiwanStock/Util/FeeSettings.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Model/OneDayStockInfo.swift
  - MyTaiwanStock/Shared/Model/OneDayStockInfo.swift
  - MyTaiwanStock/View Controller/View Model/StockDetailViewModel.swift
  - MyTaiwanStock/Model/NewsAPI.swift
  - MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewControllerTests.swift
  - MyTaiwanStockTests/Screens/Account/AccountViewControllerImportTests.swift
  - MyTaiwanStockTests/SettingViewControllerTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/ListNameTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/Shared/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock.xcdatamodel/contents
  - MyTaiwanStockTests/Screens/TradeImport/TradeEditViewControllerTests.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStock/View Controller/EditFeeViewController.swift
  - MyTaiwanStock/Screens/Account/ViewController/AccountViewController.swift
  - MyTaiwanStock/Screens/Dividend/View/DividendDetailTableViewCell.xib
  - MyTaiwanStock/View/NewsListTableViewCell2.swift
  - MyTaiwanStockTests/Screens/StockDetail/StockViewControllerTests.swift
  - MyTaiwanStock/Screens/StockDetail/ViewController/StockViewController.swift
  - MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/.xccurrentversion
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportPreviewViewControllerTests.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/ViewModel/StockCellViewModel.swift
  - MyTaiwanStock/Screens/Chat/Model/Sender.swift
  - MyTaiwanStock/View Controller/View Model/ChatViewModel.swift
  - MyTaiwanStock/TradeCost/Model/FeeSettings.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - MyTaiwanStockTests/Screens/StockList/StockListFilteringTests.swift
  - MyTaiwanStock/Screens/TradeImport/ViewController/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/Screens/Settings/SettingViewControllerTests.swift
  - MyTaiwanStock/Screens/Chat/Services/UnreadManager.swift
  - MyTaiwanStock/SharedUI/FloatingButtonManager.swift
  - MyTaiwanStock/DependencyContainer.swift
  - MyTaiwanStockTests/StoreSchemaCompatibilityCheckerTests.swift
  - MyTaiwanStock/FontManager.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/View Controller/View Model/NewsListViewModel.swift
  - MyTaiwanStock/Screens/StockDetail/ViewModel/HistoryCellModel.swift
  - MyTaiwanStock/Screens/StockList/Coordinator/StockListCoordinator.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Screens/StockDetail/Model/History.swift
  - MyTaiwanStock/OverViewCaculator.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/View Controller/StatisticViewController.swift
  - MyTaiwanStock/View/StatisticDividendTableViewCell.xib
-->

---
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

<!-- @trace
source: store-fee-and-tax
updated: 2026-10-24
code:
  - MyTaiwanStockTests/Screens/StockList/ListNameTests.swift
  - MyTaiwanStock/Screens/Dividend/View/DividendDetailTableViewCell.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStockTests/TradeCost/OverViewCalculatorTests.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Screens/Onboarding/ViewController/WalkthroughViewController.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/AddStockCellViewModel.swift
  - MyTaiwanStock/Screens/TradeImport/Services/StockNameResolver.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Screens/StockList/Model/ListStruct.swift
  - MyTaiwanStock/Screens/News/ViewController/NewsListViewController.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/View Controller/NewsListViewController.swift
  - MyTaiwanStock/Model/MyStockList.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/View Controller/StockViewController.swift
  - MyTaiwanStock/View Controller/View Model/AddDividendViewModel.swift
  - MyTaiwanStock/View/ViewController+extension.swift
  - MyTaiwanStock/Screens/Chat/Model/Channel.swift
  - MyTaiwanStock/Model/CoreData/StockNoStruct.swift
  - MyTaiwanStock/Model/FeeType.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/AddStockNoViewModel.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticStockTableViewCell.swift
  - MyTaiwanStock/Screens/StockList/Model/StockNoStruct.swift
  - MyTaiwanStock/AppCoordinator.swift
  - MyTaiwanStock/Model/Fee.swift
  - MyTaiwanStock/Screens/TradeEntry/ViewController/AddHistoryViewController.swift
  - MyTaiwanStock/Screens/TradeEntry/ViewController/MemoViewController.swift
  - MyTaiwanStock/View/NewsListCellViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticTableViewCell.swift
  - MyTaiwanStock/View Controller/AddDividendViewController.swift
  - MyTaiwanStock/StockList/View/StockTableViewCell.swift
  - MyTaiwanStock/Model/StockInfo.swift
  - MyTaiwanStock/Screens/TradeImport/ViewModel/TradeImportViewModel.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - Localizable.xcstrings
  - MyTaiwanStock/Screens/Chat/ViewModel/ChatViewModel.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/View/AddStockCellViewModel.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Screens/Dividend/ViewModel/AddDividendViewModel.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportViewModelTests.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticStockTableViewCell.xib
  - MyTaiwanStock/Screens/Chat/Model/Message.swift
  - MyTaiwanStock/Screens/StockList/ViewController/AddListViewController.swift
  - MyTaiwanStock/Util/ICloudBackupService.swift
  - MyTaiwanStock/Screens/StockDetail/View/NewHistoryTableViewCell.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewModelTests.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Screens/StockList/View/StockTableViewCell.swift
  - MyTaiwanStockTests/Screens/StockList/DuplicateStockNoTests.swift
  - MyTaiwanStock/Screens/Chat/ViewController/ChatViewController.swift
  - MyTaiwanStock/Screens/StockDetail/ViewModel/StockDetailViewModel.swift
  - MyTaiwanStock/View/AddStockTableViewCell.swift
  - MyTaiwanStock/View/HistoryCellModel.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStock/Screens/TradeEntry/ViewModel/AddHistoryViewModel.swift
  - MyTaiwanStock/Util/FeeCalculator.swift
  - MyTaiwanStock/Screens/Statistics/ViewModel/StatisticViewModel.swift
  - MyTaiwanStock/View/DividendDetailTableViewCell.xib
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/View Controller/View Model/AddHistoryViewModel.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Shared/Model/StockListEntry.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticDividendTableViewCell.swift
  - MyTaiwanStockTests/TradeCost/FeeCalculatorTests.swift
  - MyTaiwanStock/Shared/Model/HistoryOnline.swift
  - MyTaiwanStock/Shared/Model/MyTaiwanStock.xcdatamodeld/.xccurrentversion
  - MyTaiwanStockTests/Screens/TradeImport/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Screens/News/ViewController/webViewController.swift
  - MyTaiwanStock/View/StatisticStockTableViewCell.xib
  - MyTaiwanStock/Model/Channel.swift
  - MyTaiwanStock/App/AppDelegate.swift
  - MyTaiwanStockTests/TradeCost/FeeTaxFieldsTests.swift
  - MyTaiwanStock/Model/Message.swift
  - MyTaiwanStock/Screens/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/NewHistoryTableViewCell.swift
  - MyTaiwanStock/Screens/StockDetail/Model/StockInfo.swift
  - MyTaiwanStock/Screens/Dividend/ViewController/AddDividendViewController.swift
  - MyTaiwanStock/Screens/Statistics/ViewController/StatisticViewController.swift
  - MyTaiwanStock/View Controller/AddStockNoViewController.swift
  - MyTaiwanStock/App/SceneDelegate.swift
  - MyTaiwanStock/View Controller/AddHistoryViewController.swift
  - MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock 2.xcdatamodel/contents
  - MyTaiwanStock/Screens/News/View/NewsListTableViewCell2.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Repository/NetworkService.swift
  - MyTaiwanStock/Screens/TradeImport/Services/TradeTextRecognizer.swift
  - MyTaiwanStock/View Controller/WalkthroughViewController.swift
  - MyTaiwanStockTests/ICloudBackupServiceTests.swift
  - MyTaiwanStock/Model/StockStatistic.swift
  - MyTaiwanStock/TradeCost/Services/OverViewCalculator.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStock/Screens/News/ViewModel/NewsListCellViewModel.swift
  - MyTaiwanStock/Screens/Settings/ViewController/SettingViewController.swift
  - MyTaiwanStock/View Controller/View Model/AddListViewModel.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/AddListViewModel.swift
  - MyTaiwanStock/Screens/StockList/Model/FavList.swift
  - MyTaiwanStock/Screens/TradeImport/Coordinator/TradeImportFlow.swift
  - MyTaiwanStock/View/DividendDetailTableViewCell.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/View/StatisticDividendTableViewCell.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStockTests/Screens/StockList/StockListRefresherTests.swift
  - MyTaiwanStock/SharedUI/FontManager.swift
  - MyTaiwanStock/Screens/TradeImport/Services/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/testOverViewCalculator.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeScreenshotParserTests.swift
  - MyTaiwanStock/Screens/StockList/ViewController/AddStockNoViewController.swift
  - MyTaiwanStock/View Controller/AddListViewController.swift
  - MyTaiwanStock/App/DependencyContainer.swift
  - MyTaiwanStock/App/AppCoordinator.swift
  - MyTaiwanStock/Screens/Statistics/View/StatisticDividendTableViewCell.xib
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/Screens/StockList/AddStockNoViewModelTests.swift
  - MyTaiwanStock/View Controller/webViewController.swift
  - MyTaiwanStock/View Controller/AccountViewController.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/TradeCost/Model/FeeTaxFields.swift
  - MyTaiwanStock/TradeCost/Services/FeeCalculator.swift
  - MyTaiwanStock/View/StatisticTableViewCell.swift
  - MyTaiwanStock/Model/OnlineDB/FavList.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/SharedUI/FloatingButtonManagerTests.swift
  - MyTaiwanStock/View Controller/DividendDetailViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportFlowTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/Screens/StockList/StockListCoordinatorImportTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/EditFeeViewController.swift
  - MyTaiwanStock/View Controller/CustomTabBarViewController.swift
  - MyTaiwanStock/Screens/TradeImport/ViewController/TradeEditViewController.swift
  - MyTaiwanStock/Model/Sender.swift
  - MyTaiwanStockTests/HistoryOnlineTests.swift
  - MyTaiwanStockTests/FeeCalculatorTests.swift
  - MyTaiwanStock/App/CustomTabBarViewController.swift
  - MyTaiwanStock/Screens/TradeImport/Services/TradeImageSource.swift
  - MyTaiwanStock/StockList/TradeImageSource.swift
  - MyTaiwanStock/View/StatisticStockTableViewCell.swift
  - MyTaiwanStockTests/BackupDestinationTests.swift
  - MyTaiwanStock/Screens/StockList/ViewModel/StockCellViewModel.swift
  - MyTaiwanStock/SharedUI/ViewController+extension.swift
  - MyTaiwanStock/Screens/News/Model/NewsAPI.swift
  - docs/architecture/source-layout.md
  - MyTaiwanStock/Screens/TradeImport/Services/TradeScreenshotParser.swift
  - MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock.xcdatamodel/contents
  - MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - MyTaiwanStock/Model/OnlineDB/HistoryOnline.swift
  - MyTaiwanStockTests/Screens/TradeImport/DefaultTradeImportStoreTests.swift
  - MyTaiwanStockTests/Screens/StockList/TestStockListViewModel.swift
  - MyTaiwanStockTests/DuplicateStockNoTests.swift
  - MyTaiwanStock/Screens/TradeImport/Model/TradeImportModels.swift
  - MyTaiwanStock/View Controller/View Model/StatisticViewModel.swift
  - MyTaiwanStock/SharedUI/FloatingButton.swift
  - MyTaiwanStock/Screens/Statistics/Model/StockStatistic.swift
  - MyTaiwanStockTests/FeeSettingsTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Screens/StockList/View/AddStockTableViewCell.swift
  - MyTaiwanStock/Util/BackupDestination.swift
  - MyTaiwanStock/View Controller/MemoViewController.swift
  - MyTaiwanStockTests/Screens/StockDetail/StockDetailOverviewTests.swift
  - MyTaiwanStockTests/StockListCoordinatorImportTests.swift
  - MyTaiwanStockTests/TradeImportFlowTests.swift
  - MyTaiwanStock/View Controller/ChatViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/StockNameResolverTests.swift
  - MyTaiwanStock/Screens/Dividend/ViewController/DividendDetailViewController.swift
  - MyTaiwanStock/Screens/StockDetail/View/NewHistoryTableViewCell.xib
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/Shared/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock 2.xcdatamodel/contents
  - MyTaiwanStock/Screens/News/ViewModel/NewsListViewModel.swift
  - MyTaiwanStock/UnreadManager.swift
  - MyTaiwanStock/Model/History.swift
  - MyTaiwanStock/Screens/StockList/Model/MyStockList.swift
  - MyTaiwanStockTests/TradeCost/FeeSettingsTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/View/NewHistoryTableViewCell.xib
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStock/Model/CoreData/ListStruct.swift
  - MyTaiwanStock/Util/FeeSettings.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Model/OneDayStockInfo.swift
  - MyTaiwanStock/Shared/Model/OneDayStockInfo.swift
  - MyTaiwanStock/View Controller/View Model/StockDetailViewModel.swift
  - MyTaiwanStock/Model/NewsAPI.swift
  - MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewControllerTests.swift
  - MyTaiwanStockTests/Screens/Account/AccountViewControllerImportTests.swift
  - MyTaiwanStockTests/SettingViewControllerTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/ListNameTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/Shared/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock.xcdatamodel/contents
  - MyTaiwanStockTests/Screens/TradeImport/TradeEditViewControllerTests.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStock/View Controller/EditFeeViewController.swift
  - MyTaiwanStock/Screens/Account/ViewController/AccountViewController.swift
  - MyTaiwanStock/Screens/Dividend/View/DividendDetailTableViewCell.xib
  - MyTaiwanStock/View/NewsListTableViewCell2.swift
  - MyTaiwanStockTests/Screens/StockDetail/StockViewControllerTests.swift
  - MyTaiwanStock/Screens/StockDetail/ViewController/StockViewController.swift
  - MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/.xccurrentversion
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportPreviewViewControllerTests.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/ViewModel/StockCellViewModel.swift
  - MyTaiwanStock/Screens/Chat/Model/Sender.swift
  - MyTaiwanStock/View Controller/View Model/ChatViewModel.swift
  - MyTaiwanStock/TradeCost/Model/FeeSettings.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View Controller/SettingViewController.swift
  - MyTaiwanStockTests/Screens/StockList/StockListFilteringTests.swift
  - MyTaiwanStock/Screens/TradeImport/ViewController/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/Screens/Settings/SettingViewControllerTests.swift
  - MyTaiwanStock/Screens/Chat/Services/UnreadManager.swift
  - MyTaiwanStock/SharedUI/FloatingButtonManager.swift
  - MyTaiwanStock/DependencyContainer.swift
  - MyTaiwanStockTests/StoreSchemaCompatibilityCheckerTests.swift
  - MyTaiwanStock/FontManager.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/View Controller/View Model/NewsListViewModel.swift
  - MyTaiwanStock/Screens/StockDetail/ViewModel/HistoryCellModel.swift
  - MyTaiwanStock/Screens/StockList/Coordinator/StockListCoordinator.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Screens/StockDetail/Model/History.swift
  - MyTaiwanStock/OverViewCaculator.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/View Controller/StatisticViewController.swift
  - MyTaiwanStock/View/StatisticDividendTableViewCell.xib
-->