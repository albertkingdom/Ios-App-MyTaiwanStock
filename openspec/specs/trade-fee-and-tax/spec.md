# trade-fee-and-tax Specification

## Purpose

Defines how the app computes, stores, uploads and displays the brokerage fee and the securities transaction tax of each buy and sell record, and how they are merged into holdings, average buy price and profit.

## Requirements

### Requirement: Calculate fee and tax with one rule set

The system SHALL compute the fee and the transaction tax of a trade with one calculation that uses decimal arithmetic, and SHALL return no result when the price is not greater than 0 or the share count is less than 1. The trade value SHALL be the price multiplied by the number of shares, without rounding. A fee discount stored as a binary floating-point number SHALL be converted to a decimal through its shortest decimal text, so that a discount of 2.8 is exactly 2.8. The fee SHALL be the trade value multiplied by 0.001425 and by the fee discount divided by 10, rounded down to a whole New Taiwan dollar, where a discount of 10 means no discount, and the fee SHALL then be raised to the minimum fee that applies: the whole-lot minimum fee when the trade has 1000 shares or more, and the odd-lot minimum fee when the trade has fewer than 1000 shares. The two minimum fees SHALL be the values the user saved in the settings, and SHALL be 20 for a whole lot and 1 for an odd lot when nothing was saved; a minimum fee of 0 means that no minimum applies to that kind of trade. The tax SHALL be 0 for a buy. For a sell, the tax SHALL be the trade value multiplied by the tax rate of the chosen category, rounded down to a whole dollar, where the categories are general stock 0.3%, same-day stock trade 0.15%, ETF 0.1% and exempt 0%. A trade of 1000 shares or more that is not a multiple of 1000 SHALL use the whole-lot minimum fee.

#### Scenario: Buy without discount

- **WHEN** the user buys 1000 shares at a price of 100 with a discount of 10
- **THEN** the fee SHALL be 142 and the tax SHALL be 0

#### Scenario: Fee below the minimum is raised

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6 and the saved whole-lot minimum fee is 20
- **THEN** the calculated fee of 17 SHALL be raised to the whole-lot minimum of 20

#### Scenario: Odd-lot minimum fee from the settings

- **WHEN** the user buys 5 shares at a price of 112.55 with a discount of 6 and the saved odd-lot minimum fee is 5
- **THEN** the calculated fee of 0 SHALL be raised to the odd-lot minimum of 5

#### Scenario: Whole-lot minimum fee from the settings

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6 and the saved whole-lot minimum fee is 30
- **THEN** the fee SHALL be 30

#### Scenario: No minimum fee

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6 and the saved whole-lot minimum fee is 0
- **THEN** the fee SHALL be the calculated 17

#### Scenario: Minimum fees are not saved

- **WHEN** no minimum fee was ever saved and the user buys 5 shares at a price of 112.55 with a discount of 6
- **THEN** the fee SHALL be the default odd-lot minimum of 1

#### Scenario: Decimal discount without a rounding error

- **WHEN** the discount is 2.8 and the user sells 1000 shares at a price of 1000
- **THEN** the fee SHALL be 399, not 398

#### Scenario: Invalid trade has no result

- **WHEN** the price is 0 or the share count is 0
- **THEN** the calculation SHALL return no fee and no tax

##### Example: fee and tax by trade

| Side | Shares | Price | Discount | Whole-lot minimum | Odd-lot minimum | Category | Fee | Tax |
| ---- | ------ | ----- | -------- | ----------------- | --------------- | -------- | --- | --- |
| Buy | 1000 | 100 | 10 | 20 | 1 | general stock | 142 | 0 |
| Sell | 1000 | 105 | 6 | 20 | 1 | general stock | 89 | 315 |
| Buy | 5 | 112.55 | 6 | 20 | 1 | general stock | 1 | 0 |
| Sell | 10 | 757 | 6 | 20 | 1 | general stock | 6 | 22 |
| Buy | 1 | 2470 | 6 | 20 | 1 | general stock | 2 | 0 |
| Buy | 1000 | 20 | 6 | 20 | 1 | general stock | 20 | 0 |
| Sell | 2000 | 22 | 6 | 20 | 1 | ETF | 37 | 44 |
| Sell | 1000 | 100 | 10 | 20 | 1 | exempt | 142 | 0 |
| Buy | 999 | 1 | 10 | 20 | 1 | general stock | 1 | 0 |
| Buy | 1500 | 1 | 10 | 20 | 1 | general stock | 20 | 0 |
| Buy | 5 | 112.55 | 6 | 20 | 5 | general stock | 5 | 0 |
| Buy | 1000 | 20 | 6 | 30 | 1 | general stock | 30 | 0 |
| Buy | 1000 | 20 | 6 | 0 | 1 | general stock | 17 | 0 |


<!-- @trace
source: fee-settings-rework
updated: 2026-10-25
code:
  - MyTaiwanStockTests/Screens/TradeImport/TradeEditViewControllerTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStockTests/Screens/TradeImport/DefaultTradeImportStoreTests.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportPreviewViewControllerTests.swift
  - docs/architecture/source-layout.md
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewModelTests.swift
  - MyTaiwanStockTests/Screens/Settings/FeeSettingsViewControllerTests.swift
  - MyTaiwanStock/TradeCost/Services/FeeCalculator.swift
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/TradeCost/FeeSettingsTests.swift
  - MyTaiwanStock/Util/UserDefault+Extension.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/Screens/Settings/SettingViewControllerTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/SettingViewController.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewControllerTests.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Screens/Settings/ViewController/EditFeeViewController.swift
  - MyTaiwanStock/TradeCost/Model/FeeSettings.swift
  - MyTaiwanStockTests/TradeCost/FeeCalculatorTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/FeeSettingsViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportViewModelTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStockTests/ValidInputServiceTest.swift
-->

---
### Requirement: Store fee and tax with each record

The system SHALL store the fee and the tax as optional whole-dollar numbers on each buy and sell record. A record without a stored fee or tax is a record whose fee or tax is unknown, and the system SHALL distinguish an unknown value from a stored value of 0. Records created by manual entry or by screenshot import SHALL carry the fee and the tax that were shown to the user when the record was saved. A record created by manual entry or by screenshot import SHALL always have a fee and a tax; only records saved before this capability have unknown values. The tax of a buy record SHALL always be stored as 0.

#### Scenario: New record keeps the shown values

- **WHEN** the user saves a sell of 10 shares at 757 with the fee field showing 6 and the tax field showing 22
- **THEN** the stored record SHALL have a fee of 6 and a tax of 22

#### Scenario: Existing record has unknown fee

- **WHEN** a record that was saved before this capability exists is displayed
- **THEN** its fee and tax SHALL be unknown, SHALL be shown as a dash, and SHALL NOT be shown as 0


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
### Requirement: Keep existing data when the database is upgraded

When the app starts with a database that was created before fee and tax were stored, the system SHALL keep every existing record unchanged and SHALL leave the new fee and tax values of those records unknown. The system SHALL NOT delete or reset the database to perform the upgrade.

#### Scenario: Upgrade with existing records

- **GIVEN** a database with three buy records and two sell records created before this capability
- **WHEN** the app starts after the upgrade
- **THEN** all five records SHALL be present with the same stock number, price, shares, date and side
- **AND** the fee and tax of all five SHALL be unknown


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
### Requirement: Upload fee and tax to Firestore

When a record is uploaded to Firestore, the system SHALL include the fee and the tax in the document when they are known and SHALL omit them when they are unknown. This SHALL apply to a record saved by manual entry, a record saved by screenshot import, and a local record uploaded when the user signs in and chooses to import local data. The system SHALL NOT download history records from Firestore as part of this capability.

#### Scenario: Upload with fee and tax

- **WHEN** a record with a fee of 6 and a tax of 22 is uploaded
- **THEN** the document SHALL contain the fee 6 and the tax 22 together with the existing fields

#### Scenario: Upload with unknown fee

- **WHEN** a record whose fee and tax are unknown is uploaded
- **THEN** the document SHALL contain no fee field and no tax field

#### Scenario: Local data imported after sign-in

- **WHEN** the user signs in and imports a local record that has a fee of 142
- **THEN** the uploaded document SHALL contain the fee 142


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
### Requirement: Enter fee and tax when adding a record by hand

On the add-record screen the system SHALL compute the fee from the final text of the price and shares fields, using the fee discount and the minimum fees from the settings screen, every time the price or the shares change, when the side changes between buy and sell, and when the tax category changes. The fee and the tax SHALL be shown in editable fields that contain only the number; the unit SHALL be shown beside the field. For a sell, the system SHALL show the tax field and a choice of tax category with general stock as the default and SHALL compute the tax from the chosen category; for a buy the system SHALL NOT show a tax field and SHALL store a tax of 0. When the user types in the fee field or the tax field, that field SHALL keep the user's value when the price, the shares, the side or the category change afterwards. While the user is editing, an empty field SHALL stay empty so that a new number can be typed, and when the user leaves a field that is still empty the system SHALL show the computed value again and SHALL compute that field automatically again. The system SHALL store the values shown in the fields. The system SHALL reject a share count above 32767, and a fee or tax that is negative, not a whole number, or above 2147483647, SHALL show an input error for it and SHALL NOT write a record.

#### Scenario: Fee follows the final text

- **WHEN** the price field shows 100 and the user types the shares one character at a time, ending with 1000
- **THEN** the fee field SHALL show the fee computed for 1000 shares after the last character is typed

#### Scenario: Sell shows tax controls

- **WHEN** the user switches the record to a sell
- **THEN** the system SHALL show the tax field and the tax category choice and SHALL compute the tax from the price and shares

#### Scenario: Switching the side recomputes

- **WHEN** the price is 105, the shares are 1000, the side is a buy, and the user switches to a sell
- **THEN** the tax SHALL be computed for the sell

#### Scenario: Manual value is kept

- **WHEN** the user types 50 in the fee field and then changes the shares
- **THEN** the fee field SHALL still show 50

#### Scenario: Retyping after deleting the value

- **WHEN** the fee field shows 142, the user deletes all digits and types 50
- **THEN** the fee field SHALL show 50 and the stored fee SHALL be 50

#### Scenario: Leaving the field empty

- **WHEN** the user deletes all digits of the fee field and leaves the field without typing
- **THEN** the fee field SHALL show the computed fee again

#### Scenario: Minimum fee from the settings

- **WHEN** the saved odd-lot minimum fee is 5 and the user enters a buy of 5 shares at a price of 112.55 with a discount of 6
- **THEN** the fee field SHALL show 5

#### Scenario: Too many shares

- **WHEN** the user saves a record with 32768 shares
- **THEN** the system SHALL show an input error
- **AND** the system SHALL NOT write a record and SHALL NOT crash


<!-- @trace
source: fee-settings-rework
updated: 2026-10-25
code:
  - MyTaiwanStockTests/Screens/TradeImport/TradeEditViewControllerTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStockTests/Screens/TradeImport/DefaultTradeImportStoreTests.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportPreviewViewControllerTests.swift
  - docs/architecture/source-layout.md
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewModelTests.swift
  - MyTaiwanStockTests/Screens/Settings/FeeSettingsViewControllerTests.swift
  - MyTaiwanStock/TradeCost/Services/FeeCalculator.swift
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/TradeCost/FeeSettingsTests.swift
  - MyTaiwanStock/Util/UserDefault+Extension.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/Screens/Settings/SettingViewControllerTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/SettingViewController.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewControllerTests.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Screens/Settings/ViewController/EditFeeViewController.swift
  - MyTaiwanStock/TradeCost/Model/FeeSettings.swift
  - MyTaiwanStockTests/TradeCost/FeeCalculatorTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/FeeSettingsViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportViewModelTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStockTests/ValidInputServiceTest.swift
-->

---
### Requirement: Compute holdings and cost with sells and fees

For one stock, the system SHALL compute the holdings as the total shares bought minus the total shares sold, and SHALL show a negative result as it is. The system SHALL compute the average buy price including fees as the sum of the buy values and the buy fees divided by the total shares bought, where an unknown fee counts as 0, and SHALL show it as a dash when there are no buys. The average sell price SHALL be the sum of the sell values divided by the total shares sold, without fees, and SHALL be shown as a dash when there are no sells. The system SHALL show average prices rounded half up to two decimal places. The market value SHALL be shown only when the holdings are greater than 0, and as a dash otherwise. For a buy record, the profit percentage SHALL be the current price minus the fee-inclusive unit cost, divided by the fee-inclusive unit cost, multiplied by 100, where the fee-inclusive unit cost is the buy value plus the fee, divided by the shares. The profit percentage SHALL be derived from a number, so that a positive value and a negative value are shown in their own colors. A sell record SHALL keep showing no profit percentage. The stock detail screen SHALL label the average buy price as including fees. When the average buy price changes to a dash, the screen SHALL update the label to the dash.

#### Scenario: Buy and sell the same shares

- **WHEN** the user bought 1000 shares at 100 and sold 1000 shares at 105
- **THEN** the holdings SHALL be 0
- **AND** the average buy price SHALL be 100 plus the buy fee divided by 1000

#### Scenario: Partial sell

- **WHEN** the user bought 1000 shares and sold 400 shares
- **THEN** the holdings SHALL be 600

#### Scenario: Only sell records

- **WHEN** a stock has only sell records
- **THEN** the holdings SHALL be shown as negative, the market value SHALL be shown as a dash, and the average buy price SHALL be shown as a dash
- **AND** the system SHALL NOT divide by zero

#### Scenario: Last buy is deleted

- **WHEN** the user deletes the only buy record of a stock that also has a sell record
- **THEN** the average buy price label SHALL change to a dash and SHALL NOT keep the earlier value

##### Example: average buy price including fees

- **GIVEN** a buy of 1000 shares at 100 with a fee of 142, and a buy of 1000 shares at 110 with a fee of 156
- **WHEN** the stock detail screen is shown
- **THEN** the average buy price including fees SHALL be 105.149, shown as 105.15

##### Example: rounding of an average price

- **GIVEN** a buy of 1000 shares at 100 with a fee of 145
- **WHEN** the stock detail screen is shown
- **THEN** the average buy price including fees SHALL be 100.145, shown as 100.15

##### Example: profit of a buy record

- **GIVEN** a buy of 1000 shares at 100 with a fee of 142 and a current price of 105
- **WHEN** the record is shown
- **THEN** the profit percentage SHALL be 4.85 percent, shown in the color of a positive value


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
### Requirement: Show fee and tax per record and flag missing fee data

The records list of the stock detail screen SHALL show the fee and the tax of each record on a second line of the record row, with a dash for an unknown value, and SHALL remain readable at the largest Dynamic Type size without truncating the first line. When at least one buy record of the stock has an unknown fee, the stock detail screen SHALL show a note next to the average buy price that some records have no fee data. Sell records with an unknown fee SHALL NOT cause the note.

#### Scenario: Mixed buy records

- **WHEN** a stock has one buy record with a stored fee and one buy record from before this capability
- **THEN** the first record SHALL show its fee, the second SHALL show a dash, and the note SHALL be shown

#### Scenario: Old sell record only

- **WHEN** the only record without a fee is a sell record
- **THEN** the note SHALL NOT be shown

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
### Requirement: Choose the fee discount and minimum fees in settings

The settings screen SHALL show the fee settings as one row that states the saved fee discount and the two minimum fees, for example "2.8 折・最低 20 / 1 元", and "無折扣・最低 20 / 1 元" when the discount is 10. Selecting the row SHALL open a settings page with three fields: the fee discount, the whole-lot minimum fee and the odd-lot minimum fee. The fee discount SHALL be a number from 0.1 to 10 with at most two decimal places, where 10 means no discount. Each minimum fee SHALL be a whole number of dollars from 0 to 2147483647. When the user saves the page, the system SHALL validate the three values together; when any of them is invalid, the system SHALL show an error that names the invalid value (the first invalid one in the order discount, whole-lot minimum fee, odd-lot minimum fee), SHALL NOT save any of the three values, and SHALL keep the page open with what the user typed. When the user returns to the settings screen, the row SHALL show the values that are saved. When no discount has been saved, the discount SHALL be 10; when only the earlier discount choice, a whole-number position, was saved, the system SHALL read it as the discount equal to that position plus one, without changing what is stored. When no minimum fee has been saved, or a saved minimum fee is not a whole number from 0 to 2147483647, that minimum fee SHALL be the default: 20 for the whole-lot minimum fee and 1 for the odd-lot minimum fee. The fee mode and the fixed fee amount that an earlier version saved SHALL be ignored, and SHALL NOT be changed or deleted.

#### Scenario: Decimal discount

- **WHEN** the user enters a discount of 2.8 and saves
- **THEN** the system SHALL compute fees with a discount of 2.8

#### Scenario: Discount out of range

- **WHEN** the user enters a discount of 0 or of 11 and saves
- **THEN** the system SHALL show an error, SHALL NOT save any value and SHALL keep the page open

#### Scenario: Discount with three decimal places

- **WHEN** the user enters a discount of 2.855 and saves
- **THEN** the system SHALL show an error and SHALL NOT save any value

#### Scenario: Earlier discount choice

- **WHEN** the earlier saved choice is the sixth entry and no new discount is saved
- **THEN** the discount SHALL be 6

#### Scenario: Minimum fees are saved

- **WHEN** the user enters a whole-lot minimum fee of 20 and an odd-lot minimum fee of 5 and saves
- **THEN** the system SHALL compute fees with an odd-lot minimum of 5

#### Scenario: Saved minimum fee that is not usable

- **WHEN** the stored odd-lot minimum fee is the text "20" or the number 20.5 or -1
- **THEN** the odd-lot minimum fee SHALL be the default of 1

#### Scenario: Minimum fee that is not valid

- **WHEN** the user enters, in the whole-lot minimum fee field or in the odd-lot minimum fee field, a value of "-1", "20.5", "abc", "" or 2147483648 and saves
- **THEN** the system SHALL show an error that names that minimum fee and SHALL NOT save any value

#### Scenario: One invalid value blocks all three

- **WHEN** the user enters a valid discount of 2.8 and an invalid minimum fee and saves
- **THEN** the saved discount and both saved minimum fees SHALL stay as they were before

#### Scenario: Several invalid values

- **WHEN** the user enters a discount of 11 and a whole-lot minimum fee of "-1" and saves
- **THEN** the error SHALL name the discount

#### Scenario: Summary of the saved settings

- **WHEN** the saved discount is 2.8, the whole-lot minimum fee is 20 and the odd-lot minimum fee is 1
- **THEN** the settings row SHALL read "2.8 折・最低 20 / 1 元"

#### Scenario: Nothing saved

- **WHEN** no fee setting was ever saved
- **THEN** the settings row SHALL read "無折扣・最低 20 / 1 元"

#### Scenario: Fixed fee from an earlier version

- **WHEN** a user who saved the fixed-amount fee mode in an earlier version starts the app after the upgrade
- **THEN** the system SHALL compute fees with the discount formula
- **AND** the earlier mode and amount SHALL remain stored without being read

##### Example: earlier fixed fee is ignored

- **GIVEN** the stored fee mode is "fixedAmount", the stored fixed amount is 30, and no discount and no minimum fee were saved
- **WHEN** the user buys 1000 shares at a price of 100
- **THEN** the fee SHALL be 142, not 30

<!-- @trace
source: fee-settings-rework
updated: 2026-10-25
code:
  - MyTaiwanStockTests/Screens/TradeImport/TradeEditViewControllerTests.swift
  - MyTaiwanStock/zh-Hant.lproj/Main.strings
  - MyTaiwanStockTests/Screens/TradeImport/DefaultTradeImportStoreTests.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportPreviewViewControllerTests.swift
  - docs/architecture/source-layout.md
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewModelTests.swift
  - MyTaiwanStockTests/Screens/Settings/FeeSettingsViewControllerTests.swift
  - MyTaiwanStock/TradeCost/Services/FeeCalculator.swift
  - MyTaiwanStock/en.lproj/Main.strings
  - MyTaiwanStockTests/TradeCost/FeeSettingsTests.swift
  - MyTaiwanStock/Util/UserDefault+Extension.swift
  - MyTaiwanStock/Util/ValidInputService.swift
  - MyTaiwanStockTests/Screens/Settings/SettingViewControllerTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/SettingViewController.swift
  - MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewControllerTests.swift
  - MyTaiwanStock.xcodeproj/project.pbxproj
  - MyTaiwanStock/Screens/Settings/ViewController/EditFeeViewController.swift
  - MyTaiwanStock/TradeCost/Model/FeeSettings.swift
  - MyTaiwanStockTests/TradeCost/FeeCalculatorTests.swift
  - MyTaiwanStock/Screens/Settings/ViewController/FeeSettingsViewController.swift
  - MyTaiwanStockTests/Screens/TradeImport/TradeImportViewModelTests.swift
  - MyTaiwanStock/Base.lproj/Main.storyboard
  - MyTaiwanStockTests/ValidInputServiceTest.swift
-->