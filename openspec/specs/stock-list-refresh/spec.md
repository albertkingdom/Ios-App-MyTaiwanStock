# stock-list-refresh Specification

## Purpose

The stock-list-refresh capability keeps the app's list of tradable Taiwan stock numbers current. It builds the list from official open data for listed and over-the-counter securities, stores it locally with a bundled fallback, refreshes it in the background, and uses it to validate and search stock numbers.

## Requirements

### Requirement: Build the list from official open data

The system SHALL build the stock list from two official sources: the Taiwan Stock Exchange daily trading list (fields Code and Name) for listed securities and ETFs, and the Taipei Exchange daily close quotes (fields SecuritiesCompanyCode and CompanyName) for over-the-counter securities. Each entry SHALL carry a code, a name and a market, where the market is "tse" for the first source and "otc" for the second. From the over-the-counter source the system SHALL keep an entry only when its code has at most 5 characters or starts with "00", and SHALL exclude every other entry, including warrants whose 6-character codes start with 70, 71, 72 or 73. When the same code appears in both sources, the system SHALL keep the Taiwan Stock Exchange entry.

#### Scenario: Over-the-counter warrants are excluded

- **WHEN** the over-the-counter source contains the codes 710000, 700019, 73000U, 72400U, 6488, 00679B, 006201 and 00411A
- **THEN** the resulting list SHALL contain 6488, 00679B, 006201 and 00411A with market "otc"
- **AND** the resulting list SHALL NOT contain 710000, 700019, 73000U or 72400U

##### Example: filtering rule

| Code | Source | Kept | Reason |
| --- | --- | --- | --- |
| 6488 | Taipei Exchange | yes | 4 characters |
| 00679B | Taipei Exchange | yes | starts with 00 |
| 710000 | Taipei Exchange | no | 6 characters, starts with 71 |
| 73000U | Taipei Exchange | no | 6 characters, starts with 73 |
| 00981A | Taiwan Stock Exchange | yes | all entries kept |

#### Scenario: Code present in both sources

- **WHEN** the same code appears in both sources
- **THEN** the system SHALL keep one entry with market "tse"


<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->

---
### Requirement: Load the list from cache with a bundled fallback

The system SHALL load the stock list from the local cache file when it exists, can be decoded and contains at least one entry, and SHALL otherwise load the bundled fallback list shipped inside the app. The list provided to the rest of the app SHALL NOT be empty.

#### Scenario: Valid cache

- **WHEN** the cache file exists and decodes to a non-empty list
- **THEN** the system SHALL provide the cached list

#### Scenario: Missing or corrupted cache

- **WHEN** the cache file does not exist or cannot be decoded
- **THEN** the system SHALL provide the bundled fallback list


<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->

---
### Requirement: Refresh the list in the background when stale

The system SHALL check whether a refresh is needed when the app launches and when it returns to the foreground. A refresh SHALL start when no cached list exists or when at least 7 days have passed since the last successful refresh. The refresh SHALL run in the background and SHALL NOT block the user interface.

#### Scenario: Refresh timing

- **WHEN** the app returns to the foreground
- **THEN** the system SHALL decide to refresh or skip according to the time since the last successful refresh

##### Example: refresh decision

| Last successful refresh | Cache exists | Refresh |
| --- | --- | --- |
| 6 days ago | yes | no |
| 7 days ago | yes | yes |
| never | no | yes |


<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->

---
### Requirement: Protect the list from bad refresh results

The system SHALL evaluate the two markets independently during a refresh. For each market, the system SHALL adopt the fetched entries only when the fetch and decoding succeeded and the number of entries after filtering is at least 80 percent of the number of entries that market currently has. For a market that is not adopted, the system SHALL keep its existing entries. The system SHALL replace the cache atomically and SHALL record the refresh time only when at least one market was adopted. A network error, timeout, non-success HTTP status or decoding failure SHALL leave the existing list unchanged and SHALL NOT show an error to the user.

#### Scenario: One market returns too few entries

- **WHEN** the over-the-counter market currently has 1007 entries and the fetch returns 700 entries
- **AND** the listed market fetch returns a normal number of entries
- **THEN** the system SHALL keep the existing over-the-counter entries
- **AND** the system SHALL adopt the new listed entries

##### Example: 80 percent guard

| Current entries | Fetched entries | Adopted |
| --- | --- | --- |
| 1007 | 700 | no (700 is below 805.6) |
| 1007 | 806 | yes |
| 1380 | 1380 | yes |
| 1380 | 0 | no |

#### Scenario: Both markets fail

- **WHEN** the network is unavailable during a refresh
- **THEN** the system SHALL keep the existing list
- **AND** the system SHALL NOT record a refresh time
- **AND** the system SHALL NOT show an error to the user


<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->

---
### Requirement: Run at most one refresh at a time

The system SHALL run at most one refresh at any time. When a refresh is requested while another is in progress, the system SHALL reuse the in-progress refresh and SHALL NOT start a second download. The refresh check SHALL be triggered from a single place when the app becomes active, so that a cold launch triggers it once. The stock list SHALL be read and replaced on the main actor, and after a successful refresh every later read SHALL return the new list.

#### Scenario: Two triggers at launch

- **WHEN** a refresh is requested twice while the first one is still downloading
- **THEN** the system SHALL download each source only once

#### Scenario: Read after refresh

- **WHEN** a refresh has just adopted new entries
- **THEN** the next stock search SHALL return results from the new list


<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->

---
### Requirement: Validate stock numbers by exact match

The system SHALL accept a stock number as valid only when it is exactly equal to the code of an entry in the stock list. The system SHALL NOT accept a partial code.

#### Scenario: Partial code is rejected

- **WHEN** the stock number validator is given "23"
- **THEN** the system SHALL reject it as an invalid stock number

##### Example: validation results

| Input | Result |
| --- | --- |
| 2330 | valid |
| 6488 | valid |
| 23 | invalid |
| (empty) | invalid |


<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->

---
### Requirement: Provide search strings for adding stocks

The system SHALL provide the list as strings in the form "code name", for example "6488 環球晶", and the add-stock search SHALL match the user's text as a substring of these strings.

#### Scenario: Search by name

- **WHEN** the user types "環球" in the add-stock search
- **THEN** the results SHALL include "6488 環球晶"

<!-- @trace
source: refresh-stock-list
updated: 2026-10-05
code:
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStock/Util/LocalDBService.swift
-->