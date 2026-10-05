# trade-screenshot-import Specification

## Purpose

The trade-screenshot-import capability lets a user turn screenshots of the Yuanta "Investor Mr." (投資先生) trade detail screen into buy/sell records in this app. It exists because that broker app offers no export function and no third-party API, so the on-screen detail list is the only available data source.

## Requirements

### Requirement: Recognize trades from screenshots on device

The system SHALL let the user pick one or more screenshots with the system photo picker and SHALL recognize the text in each image on the device using Vision text recognition with Traditional Chinese enabled and language correction disabled. The system SHALL NOT upload the screenshots or the recognized text to any server.

#### Scenario: Multiple screenshots are merged into one preview

- **WHEN** the user selects two screenshots and both contain trade rows
- **THEN** the system SHALL recognize each image and present all recognized trades together in a single preview list

#### Scenario: Screenshot without trades

- **WHEN** the recognized text of every selected screenshot contains no trade row
- **THEN** the system SHALL show a message that no importable trade was found
- **AND** the system SHALL NOT write any record

#### Scenario: Image cannot be loaded or recognized

- **WHEN** a selected image cannot be loaded or the recognition request fails
- **THEN** the system SHALL show an error message
- **AND** the system SHALL NOT write any record


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Parse two-line trade rows by position

The system SHALL parse each trade as a two-line group located by the position of the recognized text boxes, and SHALL NOT rely on the order in which text lines are returned. Positions SHALL use the Vision coordinate system, in which the origin is the lower left corner and a larger y value is higher on the screen. The lower line is located by a type text ending in "買進" or "賣出". The upper line SHALL lie above the lower line, within 0.5 to 2.5 times the height of the type text box, and SHALL contain a year fragment matching four digits followed by a slash and a stock name. The upper line carries the year fragment, stock name, price and net amount; the lower line carries the month/day, trade type, share count and profit or loss. The trade direction SHALL be derived from the trade type text, and SHALL NOT be derived from text color. When the upper line cannot be found, the trade SHALL be marked incomplete and SHALL NOT borrow text from any other row.

#### Scenario: Collapsed odd-lot buy row

- **WHEN** the recognized boxes contain "2026/", "元大台灣50", "112.55", "-563" on the upper line and "09/30", "盤中零股買進", "5", "--" on the lower line
- **THEN** the system SHALL produce one trade with stock name 元大台灣50, direction buy, price 112.55, amount 5 and date 2026-09-30

##### Example: parsed trades from the sample screenshots

| Stock name | Trade type | Price | Shares | Date | Parsed direction |
| --- | --- | --- | --- | --- | --- |
| 元大台灣50 | 盤中零股買進 | 112.55 | 5 | 2026/09/30 | buy |
| 華邦電 | 盤中零股買進 | 179.50 | 3 | 2026/10/01 | buy |
| 台積電 | 盤中零股買進 | 2470.00 | 1 | 2026/09/22 | buy |
| 瑞昱 | 盤中零股賣出 | 757.00 | 10 | 2026/09/23 | sell |

#### Scenario: Thousands separator in numbers

- **WHEN** a recognized price or share text contains a thousands separator such as "1,000"
- **THEN** the system SHALL remove the separator before converting the text to a number

#### Scenario: Top row cut off by the screenshot

- **WHEN** the first trade in a screenshot shows only its lower line and the nearest text above it belongs to the summary rows
- **THEN** the system SHALL mark that trade incomplete
- **AND** the system SHALL NOT use the summary text as the stock name or price

#### Scenario: Merged text box

- **WHEN** the recognizer returns "09/30 盤中零股買進" as a single text box
- **THEN** the system SHALL still extract the month/day 09/30 and the trade type 盤中零股買進


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Ignore expanded detail block

The system SHALL ignore the expanded detail block of a trade row and the summary and header rows of the screen. Text containing the labels 委託書號, 持有成本, 價金, 手續費, 交易稅, 配息總額, 報酬率, 幣別, 沖抵明細, 總應收付, 總損益, 總價金, 總手續費 or 總交易稅, together with the values in the same row, SHALL NOT produce a trade and SHALL NOT change the parsed result of any trade. The table header texts 日期, 名稱, 價格/股數 and 應收付/損益 SHALL also be ignored.

#### Scenario: Expanded and collapsed screenshots parse the same

- **WHEN** a screenshot shows the 瑞昱 sell row expanded with 委託書號, 持有成本, 價金, 手續費 and 交易稅 rows below it
- **THEN** the system SHALL produce exactly one trade for 瑞昱
- **AND** the system SHALL NOT produce any trade from the expanded detail text


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Resolve stock number from stock name

The system SHALL resolve the stock number from the stock name by exact match against the stock list. Before matching, both the recognized name and the list name SHALL be normalized by Unicode compatibility normalization followed by removal of all whitespace characters, including full-width spaces. The system SHALL NOT use fuzzy matching. When the name matches no entry, or matches more than one entry, the trade SHALL be marked as having an unresolved stock number. A stock number entered manually in the preview SHALL be accepted only when it is exactly equal to the code of an entry in the stock list.

#### Scenario: Name found in stock list

- **WHEN** the recognized stock name is "華邦電"
- **THEN** the system SHALL resolve the stock number 2344

##### Example: name to stock number

| Recognized name | List name | Resolved stock number |
| --- | --- | --- |
| 元大台灣50 | 元大台灣50 | 0050 |
| 華邦電 | 華邦電 | 2344 |
| 台積電 | 台積電 | 2330 |
| 瑞昱 | 瑞昱 | 2379 |
| 元大MSCIA股 | 元大MSCI A股 | resolved to that entry's code |
| 不存在的股票 | (no entry) | unresolved |

#### Scenario: Name not found

- **WHEN** the recognized stock name matches no entry in the stock list
- **THEN** the system SHALL mark the trade as incomplete
- **AND** the preview SHALL require the user to enter the stock number before the trade can be selected

#### Scenario: Manually entered stock number not in the list

- **WHEN** the user enters "23" as the stock number of an unresolved trade
- **THEN** the system SHALL keep the trade incomplete and not selectable


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Restrict scope to supported trade types

The system SHALL support these trade type texts: 盤中零股買進, 盤中零股賣出, 盤後零股買進 and 盤後零股賣出, whose share column is in shares. A row whose type text ends in "買進" or "賣出" but is not one of the supported texts, such as whole-lot (現股), day trading, margin, short selling or regular investment plan rows, SHALL still be recognized as a trade, SHALL be shown in the preview as unsupported, SHALL NOT be selectable, and SHALL NOT stop the other trades from being processed.

#### Scenario: Whole-lot trade

- **WHEN** a screenshot contains a row whose type text is "現股買進"
- **THEN** the preview SHALL list that row as unsupported and not selectable

#### Scenario: Unsupported type in a batch

- **WHEN** a screenshot contains one odd-lot buy row and one row whose type text is "融資買進"
- **THEN** the preview SHALL list the odd-lot buy row as importable
- **AND** the preview SHALL list the "融資買進" row as unsupported and not selectable


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Mandatory preview with per-trade confirmation

The system SHALL present every recognized trade in a preview screen before anything is written, and SHALL NOT provide a way to import without the preview. The user SHALL be able to select or deselect each trade and to edit its stock number, price, shares, date and direction. A trade SHALL be shown as incomplete and SHALL NOT be selectable when its stock number, price, shares or date is missing, when its shares are not an integer from 1 to 32767, or when its price is not greater than 0. When a trade matches more than one status, the system SHALL show the first applicable status in this order: unsupported, incomplete, duplicate, importable. After the user edits a trade, the system SHALL recompute its status, SHALL select the trade when it becomes importable, and SHALL deselect it when it becomes duplicate or incomplete. The import action SHALL be disabled while no trade is selected.

#### Scenario: Incomplete trade cannot be selected

- **WHEN** a recognized trade has no year fragment and therefore no date
- **THEN** the preview SHALL mark it as incomplete and not selectable
- **AND** after the user enters a valid date the trade SHALL become selectable

#### Scenario: Shares out of range

- **WHEN** a trade has 33000 shares
- **THEN** the preview SHALL mark it as incomplete and not selectable

##### Example: share count validation

| Shares | Status |
| --- | --- |
| 0 | incomplete |
| 1 | valid |
| 32767 | valid |
| 32768 | incomplete |
| 33000 | incomplete |

#### Scenario: Nothing selected

- **WHEN** the user has deselected every trade
- **THEN** the import action SHALL be disabled


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Detect duplicates

The system SHALL treat two trades as duplicates when stock number, calendar date in the Asia/Taipei time zone, price, shares and direction are all equal. The system SHALL compare each previewed trade against existing local buy/sell records and against the earlier trades in the same preview. A duplicate SHALL be marked as duplicate and SHALL be deselected by default, and the user SHALL be able to select it again manually.

#### Scenario: Re-importing the same screenshot

- **WHEN** the user imports a screenshot whose trades were already imported before
- **THEN** every trade SHALL be marked as duplicate and deselected by default

##### Example: duplicate key comparison

| Existing record | New trade | Duplicate |
| --- | --- | --- |
| 0050, 2026-09-30, 112.55, 5, buy | 0050, 2026-09-30, 112.55, 5, buy | yes |
| 0050, 2026-09-30, 112.55, 5, buy | 0050, 2026-09-30, 112.55, 5, sell | no |
| 0050, 2026-09-30, 112.55, 5, buy | 0050, 2026-09-30, 112.55, 6, buy | no |
| 0050, 2026-09-30, 112.55, 5, buy | 0050, 2026-10-01, 112.55, 5, buy | no |

#### Scenario: Legitimate repeated trade

- **WHEN** the user manually selects a trade that was marked as duplicate and confirms the import
- **THEN** the system SHALL write that trade as a new record


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Write through the existing record flow

When the user confirms the import, the system SHALL first validate every selected trade, and SHALL write nothing when any selected trade is invalid. After validation passes, the system SHALL write each selected trade on the main actor through the same save-new-record flow used by manual entry, so that the local store and Firestore receive the record as they do for manual entry. The system SHALL write only stock number, direction, price, shares and date, with an empty reason. The system SHALL NOT store fees or transaction tax and SHALL NOT change the Core Data or Firestore schema. Shares SHALL be stored in the unit of shares without conversion. The stored date of an imported trade SHALL be 12:00:00.000 on the trade's calendar date in the Asia/Taipei time zone; when that millisecond timestamp is already used by an existing local record or by an earlier trade in the same batch, the system SHALL add one millisecond at a time until the timestamp is unused. The system SHALL report the number of records submitted for writing.

#### Scenario: Confirmed import writes selected trades only

- **WHEN** the preview contains three trades, two selected and one deselected, and the user confirms
- **THEN** the system SHALL call the save-new-record flow exactly twice
- **AND** the system SHALL report that two records were submitted

##### Example: odd-lot trade stored in shares

- **GIVEN** the parsed trade 元大台灣50 買進 5 股 價格 112.55 日期 2026-09-30
- **WHEN** the user confirms the import
- **THEN** the stored record has stockNo 0050, status 0 (buy), amount 5, price 112.55 and date 2026-09-30 12:00:00.000 Asia/Taipei

#### Scenario: Same-day trades get distinct timestamps

- **WHEN** the user imports one trade for 0050 and one for 2344, both dated 2026-09-30
- **THEN** the stored dates SHALL be 2026-09-30 12:00:00.000 and 2026-09-30 12:00:00.001 in the Asia/Taipei time zone
- **AND** both dates SHALL be on the same Asia/Taipei calendar day

#### Scenario: Invalid selected trade blocks the whole import

- **WHEN** one of the selected trades has an invalid share count and the user confirms
- **THEN** the system SHALL NOT write any record
- **AND** the system SHALL show an error

#### Scenario: Fees and tax are not stored

- **WHEN** the screenshot shows a fee of 6 and a transaction tax of 22 for the 瑞昱 sell row
- **THEN** the stored record SHALL contain no fee or tax value


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Choose target list for imported stocks

The preview SHALL show a list selector whose options are every existing stock list plus a "do not add to a list" option. The default selection SHALL be the list currently shown on the home screen, or "do not add to a list" when no list exists. When the user confirms the import, the system SHALL add the stock number of every imported trade to the selected list, once per distinct stock number, and SHALL skip a stock number that is already in the selected list so that no list contains the same stock number twice. The system SHALL NOT add stock numbers of trades that were not imported. The buy/sell records themselves SHALL NOT be associated with a list. When "do not add to a list" is selected, the preview SHALL show a note that the imported records cannot be opened from the home screen.

#### Scenario: Default list

- **WHEN** the user opens the preview while the home screen shows the list "My list"
- **THEN** the list selector SHALL show "My list" as selected

#### Scenario: No list exists

- **WHEN** the user opens the preview and no stock list exists
- **THEN** the list selector SHALL show "do not add to a list" as selected

#### Scenario: Imported stock not yet in the selected list

- **WHEN** the user imports a trade for stock 2379 and the selected list does not contain 2379
- **THEN** the system SHALL add 2379 to the selected list

#### Scenario: Imported stock already in the selected list

- **WHEN** the user imports two trades for stock 0050 and the selected list already contains 0050
- **THEN** the system SHALL NOT add 0050 to the list again
- **AND** the list SHALL still contain exactly one 0050

#### Scenario: Do not add to a list

- **WHEN** the user selects "do not add to a list" and confirms the import
- **THEN** the system SHALL write the buy/sell records
- **AND** the system SHALL NOT change any list

##### Example: stocks added to the selected list

| Imported trades (selected) | Selected list contains | Stocks added |
| --- | --- | --- |
| 0050 buy, 2344 buy | 0050 | 2344 |
| 2379 sell, 2379 buy | (empty) | 2379 (once) |
| 2330 buy (deselected), 2344 buy | 2344 | none |


<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->

---
### Requirement: Show imported stocks on the home screen after import

The preview SHALL be pushed onto the home screen's navigation stack and SHALL NOT be presented as a modal sheet. When the import completes, the system SHALL return to the home screen, SHALL reload the current list, SHALL update the stock numbers shared with the widget through the App Group, and SHALL reload the widget timelines, in the same way as after adding a stock manually.

#### Scenario: New stock visible immediately

- **WHEN** the user imports a trade for 2379 into the list currently shown on the home screen and the import completes
- **THEN** the home screen SHALL show 2379 in the list without leaving and re-entering the screen
- **AND** the widget timelines SHALL be reloaded

<!-- @trace
source: import-trades-from-screenshot
updated: 2026-10-05
code:
  - MyTaiwanStock/Util/TradeTextRecognizer.swift
  - MyTaiwanStockTests/ValidInputServiceTest.swift
  - MyTaiwanStock/Resources/StockList.json
  - MyTaiwanStockTests/StockListRefresherTests.swift
  - MyTaiwanStockTests/StockMarketLookupTests.swift
  - MyTaiwanStock/Util/StockListRefresher.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Util/StockListRepository.swift
  - MyTaiwanStock/SceneDelegate.swift
  - MyTaiwanStockTests/ChartServiceTests.swift
  - MyTaiwanStock/View Controller/TradeEditViewController.swift
  - MyTaiwanStockTests/AddStockNoViewModelTests.swift
  - MyTaiwanStockTests/TradeScreenshotFixtures.swift
  - MyTaiwanStock/StockList/StockListCoordinator.swift
  - MyTaiwanStockTests/HistoryDocumentSelectorTests.swift
  - MyTaiwanStock/Util/StockNameResolver.swift
  - MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift
  - MyTaiwanStock/Util/StockMarketLookup.swift
  - MyTaiwanStock/Util/StockListParser.swift
  - MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift
  - MyTaiwanStock/Util/OnlineDBService.swift
  - MyTaiwanStock/Util/TradeScreenshotParser.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/TestStockListViewModel.swift
  - MyTaiwanStock/Model/TradeImportModels.swift
  - MyTaiwanStock/AppDelegate.swift
  - MyTaiwanStock/Util/HistoryDocumentSelector.swift
  - MyTaiwanStockTests/TradeTextRecognizerTests.swift
  - MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - MyTaiwanStock/Model/StockListEntry.swift
  - MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - MyTaiwanStock/Model/StockNoList.swift
  - MyTaiwanStock/Util/ChartService.swift
  - MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - MyTaiwanStock/Util/LocalDBService.swift
  - MyTaiwanStock/View/FloatingButtonManager.swift
  - MyTaiwanStockTests/StockListRepositoryTests.swift
  - MyTaiwanStockTests/FloatingButtonManagerTests.swift
  - scripts/generate_stock_list.py
  - MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift
  - MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - MyTaiwanStockTests/StockNameResolverTests.swift
  - MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - MyTaiwanStock/View/FloatingButton.swift
  - MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - MyTaiwanStockTests/StockListFilteringTests.swift
  - MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - MyTaiwanStockTests/TradeImportViewModelTests.swift
  - MyTaiwanStock/StockList/TradeImportFlow.swift
-->