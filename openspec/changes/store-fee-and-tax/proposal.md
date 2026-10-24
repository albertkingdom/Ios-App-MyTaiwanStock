## Why

手動新增投資紀錄的手續費與證交稅目前只是新增頁上的估算顯示：沒有存進資料庫，不參與損益與買入均價，而且顯示常常算錯（稅因呼叫端寫死買進而永遠不會被算、手續費比輸入慢一個字元、折數設定沒有套用、自訂手續費存不了、零股被套用整股最低 20 元）。使用者要的是「每筆買賣紀錄都記下當時的手續費與稅，並把它們併入成本與損益」，所以要先把計算改對，再存起來。

## What Changes

- 新增純函式的手續費與稅計算（金額用 Decimal、尾數無條件捨去、整股最低 20 元、零股最低 1 元、稅只對賣出、稅率依類型：一般股票 0.3%、現股當沖 0.15%、ETF 0.1%、免稅 0%）。
- 設定頁新增手續費模式（折數或固定金額）與可輸入小數的折數；新增紀錄頁不再有折數滾輪。
- 每筆買賣紀錄新增選填的手續費與稅（整數新台幣，空值代表未知）；Core Data 新增第二版模型並以輕量遷移升級；上傳 Firestore 時帶選填的 fee 與 tax（含登入後把本機資料匯入的路徑）；iCloud 備份還原要能接受舊版本快照，並先在暫存副本確認可以遷移才取代正式資料庫。
- 手動新增頁：依最終輸入的價格與股數計算，套用設定的手續費模式，賣出時可選稅率類型，手續費與稅可修改後存入；修正自訂手續費無法儲存、超過 32767 股閃退。
- 持股數與買入均價改為正確處理賣出（目前把賣單當作買單加總）；買入均價與買進紀錄的損益改為含手續費；紀錄列表顯示每筆的手續費與稅；修正沒有買單時均價不更新、損益顏色從未生效。
- 截圖匯入寫入紀錄時一併存入估算的手續費與稅，確認預覽頁顯示並可逐筆修改，編輯後會重新估算。
- 清理手續費相關的死碼，補上先前完全沒有的手續費與稅測試。
- **BREAKING**：Core Data 模型升為第二版，舊版本的 App 無法讀取升級後的資料庫；`trade-screenshot-import` 規格中「不儲存手續費與稅、不變更資料庫結構」的要求被取代。

## Non-Goals

- 不從截圖展開明細解析券商算好的實際手續費與稅（本次匯入只存估算值，並讓使用者在預覽頁修改；解析實際值留待另一個變更）。
- 不做可設定的整股與零股最低手續費、不依日期判斷債券 ETF 免稅期限；稅率類型由使用者選擇，不從股票代碼推斷（匯入的預設類型除外，且可在預覽頁修改）。
- 不為既有紀錄回填手續費與稅；舊紀錄的手續費與稅維持空值，計算成本時視為 0。
- 不做紀錄編輯功能、不做淨損益的賣出端報表。
- 不處理 Android：使用者決定暫時不管，未來會把兩個平台拆開、Firebase 不再即時同步；Firestore 只在上傳時帶選填的 fee 與 tax，不做下載或其他同步改動。

## Capabilities

### New Capabilities

- `trade-fee-and-tax`: 手續費與證交稅的計算規則、設定、隨每筆買賣紀錄儲存與上傳、手動新增頁的輸入與修改、併入持股成本與損益的顯示。

### Modified Capabilities

- `trade-screenshot-import`: 匯入寫入紀錄時存入手續費與稅，預覽頁顯示、可修改並在編輯後重新估算，取代原本「不儲存手續費與稅」的要求。
- `icloud-backup`: 還原時接受舊版本模型的快照，並在取代正式資料庫之前先確認可以遷移。

## Impact

- Affected specs: `trade-fee-and-tax`（新增）、`trade-screenshot-import`、`icloud-backup`
- Affected code:
  - New: MyTaiwanStock/Util/FeeCalculator.swift
  - New: MyTaiwanStock/Util/FeeSettings.swift
  - New: MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/MyTaiwanStock 2.xcdatamodel
  - New: MyTaiwanStock/Model/MyTaiwanStock.xcdatamodeld/.xccurrentversion
  - New: MyTaiwanStockTests/FeeCalculatorTests.swift
  - New: MyTaiwanStockTests/FeeSettingsTests.swift
  - New: MyTaiwanStockTests/InvestHistoryMigrationTests.swift
  - New: MyTaiwanStockTests/StoreSchemaCompatibilityCheckerTests.swift
  - New: MyTaiwanStockTests/AddHistoryViewModelTests.swift
  - New: MyTaiwanStockTests/HistoryOnlineTests.swift
  - Modified: MyTaiwanStock/OverViewCaculator.swift
  - Modified: MyTaiwanStock/View/HistoryCellModel.swift
  - Modified: MyTaiwanStock/View/NewHistoryTableViewCell.swift
  - Modified: MyTaiwanStock/View/NewHistoryTableViewCell.xib
  - Modified: MyTaiwanStock/Base.lproj/Main.storyboard（新增紀錄頁與設定頁的 static table）
  - Modified: MyTaiwanStock/View Controller/AddHistoryViewController.swift
  - Modified: MyTaiwanStock/View Controller/View Model/AddHistoryViewModel.swift
  - Modified: MyTaiwanStock/View Controller/View Model/StockDetailViewModel.swift
  - Modified: MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift
  - Modified: MyTaiwanStock/View Controller/TradeEditViewController.swift
  - Modified: MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - Modified: MyTaiwanStock/View Controller/SettingViewController.swift
  - Modified: MyTaiwanStock/View Controller/EditFeeViewController.swift
  - Modified: MyTaiwanStock/View Controller/StockViewController.swift
  - Modified: MyTaiwanStock/View Controller/AccountViewController.swift
  - Modified: MyTaiwanStock/Util/ValidInputService.swift
  - Modified: MyTaiwanStock/Util/UserDefault+Extension.swift
  - Modified: MyTaiwanStock/Util/LocalDBService.swift
  - Modified: MyTaiwanStock/Util/OnlineDBService.swift
  - Modified: MyTaiwanStock/Util/DefaultTradeImportStore.swift
  - Modified: MyTaiwanStock/Util/StoreSchemaCompatibilityChecking.swift
  - Modified: MyTaiwanStock/Util/ICloudBackupService.swift
  - Modified: MyTaiwanStock/Util/BackupDestination.swift
  - Modified: MyTaiwanStock/Model/OnlineDB/HistoryOnline.swift
  - Modified: MyTaiwanStock/Repository/NetworkService.swift
  - Modified: MyTaiwanStock/Repository/NetworkServiceImpl.swift
  - Modified: MyTaiwanStock.xcodeproj/project.pbxproj
  - Modified: MyTaiwanStockTests/TestStockListViewModel.swift
  - Modified: MyTaiwanStockTests/ListNameTests.swift
  - Modified: MyTaiwanStockTests/AccountViewControllerImportTests.swift
  - Modified: MyTaiwanStockTests/ICloudBackupServiceTests.swift
  - Modified: MyTaiwanStockTests/BackupDestinationTests.swift
  - Modified: MyTaiwanStockTests/testOverViewCalculator.swift
  - Modified: MyTaiwanStockTests/ValidInputServiceTest.swift
  - Modified: MyTaiwanStockTests/TradeImportViewModelTests.swift
  - Modified: MyTaiwanStockTests/DefaultTradeImportStoreTests.swift
  - Removed: MyTaiwanStock/Model/Fee.swift
  - Removed: MyTaiwanStock/Model/FeeType.swift
