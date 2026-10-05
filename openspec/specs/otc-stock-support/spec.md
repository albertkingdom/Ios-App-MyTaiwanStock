# otc-stock-support Specification

## Purpose

The otc-stock-support capability lets over-the-counter stocks be tracked like listed stocks. It selects the correct quote prefix per market, shares the market lookup with the widget extension, and keeps the stock detail screen usable when candle data is unavailable.

## Requirements

### Requirement: Query quotes with the market prefix

The system SHALL build each quote query code as "tse_{code}.tw" for a listed stock and "otc_{code}.tw" for an over-the-counter stock, based on the market recorded in the stock list. When the market of a code is unknown, the system SHALL use "tse_". This SHALL apply to the main app, the widget and the Live Activity.

#### Scenario: Mixed list

- **WHEN** the system queries quotes for 6488 (over-the-counter) and 2330 (listed)
- **THEN** the query SHALL be "otc_6488.tw|tse_2330.tw"

##### Example: prefix selection

| Code | Market in list | Query code |
| --- | --- | --- |
| 2330 | tse | tse_2330.tw |
| 6488 | otc | otc_6488.tw |
| 9999 | unknown | tse_9999.tw |


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
### Requirement: Share the market lookup with the widget

After the stock list is loaded from cache, loaded from the bundled fallback, or refreshed successfully, the system SHALL write a code-to-market lookup file into the App Group container. The widget SHALL read this file to choose the quote prefix, and SHALL use "tse_" for every code when the file is missing or cannot be read. The widget SHALL NOT load the full stock list.

#### Scenario: Lookup file written

- **WHEN** a refresh succeeds
- **THEN** the lookup file in the App Group container SHALL contain the market of every code in the new list

#### Scenario: Lookup file missing

- **WHEN** the widget builds a quote query and the lookup file does not exist
- **THEN** the widget SHALL use "tse_" for every code


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
### Requirement: Show no data when candle data is unavailable

When the candle data for a stock is empty, the stock detail screen SHALL show a no-data state in the chart area, SHALL NOT crash, and SHALL still show the buy/sell records and the overview. When the candle data has fewer rows than the 10-day moving average needs, the chart SHALL NOT crash, SHALL omit the moving average lines, and SHALL draw the candles and volume bars that exist. This SHALL apply to over-the-counter stocks, whose candle data is not supported, and to newly listed securities with few trading days.

#### Scenario: Over-the-counter stock detail

- **WHEN** the user opens the detail screen of 6488 and the candle data request returns no rows
- **THEN** the chart area SHALL show a no-data state
- **AND** the buy/sell records and overview SHALL be displayed normally

#### Scenario: Fewer rows than the moving average needs

- **WHEN** the candle data of a newly listed security has 5 rows
- **THEN** the chart SHALL NOT crash
- **AND** the chart SHALL show 5 candles without a 10-day moving average line

##### Example: row counts

| Candle rows | Result |
| --- | --- |
| 0 | no-data state |
| 3 | 3 candles, no moving average |
| 8 | 8 candles, no moving average |
| 9 | 9 candles, no moving average |
| 10 or more | candles and moving average as before |

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