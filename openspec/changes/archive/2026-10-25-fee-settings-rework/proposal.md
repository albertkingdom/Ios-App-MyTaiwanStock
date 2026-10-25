## Why

手續費設定目前是「折數」與「固定金額」二選一，但台股券商實際的差異在最低手續費（整股通常 20 元，元大等券商的盤中零股是「最低 1 元」，不是每筆固定 1 元），不是每筆固定收費；固定金額只有定期定額之類的方案才真的存在，而 App 並沒有區分下單方式。現在的設定頁還把兩種模式的兩列同時擺出來、用分段切換器選用，使用者看不出切換就是決定新增紀錄時用哪一種算法，折數的行內輸入在 Duo 上也會被鍵盤蓋住。

## What Changes

- 拿掉固定金額模式：手續費模型改為「折數（0.1 到 10，最多兩位小數）加整股最低手續費（預設 20）加零股最低手續費（預設 1）」。最低手續費由使用者設定，0 代表沒有最低門檻。
- 設定頁的手續費區塊只留一列，顯示目前設定（例如「2.8 折・最低 20 / 1 元」，沒有折扣時為「無折扣・最低 20 / 1 元」）；點進去是新的專用頁，放折數、整股最低、零股最低三個欄位，按儲存時三個值一起驗證，任何一個不合法就都不存。
- 移除設定頁的分段切換器、折數行內輸入、固定金額那一列、為鍵盤遮擋加的補丁，以及固定金額專用的編輯頁與它的驗證函式。
- 升級：舊版儲存的手續費模式與固定金額不再讀取，也不刪除、不遷移；最低手續費沒存過就用 20 與 1，所以沒用過固定金額的人算出來的結果與現在完全一樣。TestFlight 上曾選固定金額的使用者會回到折數公式。
- 新增紀錄頁與截圖匯入預覽的計算方式不變，只是最低手續費改讀設定。
- **BREAKING**：固定金額模式移除，規格中「固定金額取代公式」的情境隨之刪除。

## Non-Goals

- 不內建券商預設（選券商自動帶入折數與最低手續費）：資料會過時、要自己維護。
- 不區分下單方式（盤中、盤後、定期定額）：最低手續費只分整股（1000 股以上）與零股（不到 1000 股），1000 股以上但不是 1000 的倍數仍一律套用整股最低，與目前相同。
- 不改稅的計算、稅率類型，不改 Core Data 模型、Firestore 欄位與 iCloud 備份。
- 不為舊的固定金額設定做遷移或刪除舊的設定值。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `trade-fee-and-tax`: 手續費計算的最低手續費改為可設定並移除固定金額；設定需求改為折數加兩個最低手續費、一列摘要加專用頁；新增紀錄頁需求中的「手續費模式」字眼改為折數與最低手續費。

## Impact

- Affected specs: `openspec/specs/trade-fee-and-tax/spec.md`（三條需求：計算規則、設定、手動新增頁）。
- Affected code:
  - New: `MyTaiwanStock/Screens/Settings/ViewController/FeeSettingsViewController.swift`、`MyTaiwanStockTests/Screens/Settings/FeeSettingsViewControllerTests.swift`
  - Modified: `MyTaiwanStock/TradeCost/Model/FeeSettings.swift`、`MyTaiwanStock/TradeCost/Services/FeeCalculator.swift`、`MyTaiwanStock/Util/ValidInputService.swift`、`MyTaiwanStock/Util/UserDefault+Extension.swift`、`MyTaiwanStock/Screens/Settings/ViewController/SettingViewController.swift`、`MyTaiwanStock/Base.lproj/Main.storyboard`、`MyTaiwanStock/zh-Hant.lproj/Main.strings`、`MyTaiwanStock/en.lproj/Main.strings`、`MyTaiwanStock.xcodeproj/project.pbxproj`、`docs/architecture/source-layout.md`，以及使用 `FeeSettings(mode:)` 的測試：`MyTaiwanStockTests/TradeCost/FeeSettingsTests.swift`、`MyTaiwanStockTests/TradeCost/FeeCalculatorTests.swift`、`MyTaiwanStockTests/ValidInputServiceTest.swift`、`MyTaiwanStockTests/Screens/Settings/SettingViewControllerTests.swift`、`MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewModelTests.swift`、`MyTaiwanStockTests/Screens/TradeEntry/AddHistoryViewControllerTests.swift`、`MyTaiwanStockTests/Screens/TradeImport/TradeImportViewModelTests.swift`、`MyTaiwanStockTests/Screens/TradeImport/TradeEditViewControllerTests.swift`、`MyTaiwanStockTests/Screens/TradeImport/TradeImportPreviewViewControllerTests.swift`、`MyTaiwanStockTests/Screens/TradeImport/DefaultTradeImportStoreTests.swift`
  - Removed: `MyTaiwanStock/Screens/Settings/ViewController/EditFeeViewController.swift`
