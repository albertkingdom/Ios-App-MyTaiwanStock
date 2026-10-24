## Why

目前截圖匯入要先在券商 App 截圖、回到本 App、點 +、選「截圖匯入」，再到相簿裡找剛拍的圖。使用者希望截圖後直接從系統分享選單把圖送進本 App，少掉開 App 與翻相簿的步驟。這是截圖匯入（已上線）的後續，1.21 的截圖匯入與股票清單更新已合併，現在可以接著做。截圖含券商交易資料，所以待匯入圖片的保存時間與保護是這個功能的核心要求，不是附帶項目。

## What Changes

- 新增 Share Extension：分享選單出現「MyTaiwanStock」，只接受圖片。Extension 只把圖片複製進 App Group 共用容器的待匯入資料夾，然後顯示「已加入待匯入」並關閉；不在 extension 內辨識，也不寫入任何紀錄。
- 主 App 回到前景時檢查待匯入資料夾；有圖片且畫面上沒有其他流程或 modal 時，跳出「有 N 張待匯入的截圖，要現在匯入嗎？」。選「現在匯入」才切到列表頁根頁並沿用現有的辨識、載入畫面與確認預覽；選「稍後」則保留，下次回到前景再問。使用者在預覽頁按「匯入」前不寫入任何紀錄。
- 待匯入圖片在辨識完成後立即刪除，預覽使用記憶體中的辨識結果；最長保存 24 小時，逾時一律清除。待匯入資料夾加上檔案加密保護、排除備份、不產生縮圖、紀錄檔不寫入圖片內容。
- 匯入流程補上明確的進行中與結束狀態：預覽頁被關閉時回報，讓後續批次可以接手。
- 現有截圖匯入的圖片來源由「只有系統相簿選取器」擴充為「相簿選取器或待匯入資料夾」，並改成逐張載入、辨識；辨識與預覽行為不變。
- 新增 ShareExtension target、App ID、簽署與 provisioning profile 設定，沿用既有的 App Group；把新的 bundle id 加進 fastlane 的簽署流程與 CI 的建置檢查；版號改為 1.23（1.22 已上傳 TestFlight）。簽署是最容易出問題的部分，列為第一個任務並在功能開發前做一次完整的封存乾跑。

## Non-Goals

- 不在 extension 內做文字辨識：extension 的記憶體上限小，辨識留在主 App。
- 不在使用者未確認前寫入任何買賣紀錄。
- 預覽顯示期間不保留圖片：預覽期間 App 被系統回收時，使用者需要重新分享。
- 不嘗試由 extension 自動開啟主 App：系統沒有可靠的公開做法，也不在本次加入本機通知。
- 不處理圖片以外的分享內容（文字、網址、PDF）。
- 不上傳圖片或辨識文字到任何伺服器，也不同步或備份待匯入資料夾。
- 不處理 Android 端。

## Capabilities

### New Capabilities

- `share-extension-import`: 從系統分享選單把圖片放進待匯入資料夾、主 App 詢問後接手匯入，以及圖片的保存、刪除與保護規則。

### Modified Capabilities

- `trade-screenshot-import`: 圖片來源除了系統相簿選取器，也可以是待匯入資料夾；辨識、預覽與寫入前確認的要求維持不變。

## Impact

- Affected specs: `share-extension-import`（新增）、`trade-screenshot-import`（修改圖片來源）
- Affected code:
  - New: ShareExtension/ShareViewController.swift
  - New: ShareExtension/Info.plist
  - New: ShareExtension/ShareExtension.entitlements
  - New: MyTaiwanStock/ShareImport/SharedWithExtension/PendingImportStore.swift
  - New: MyTaiwanStock/ShareImport/PendingImportCoordinator.swift
  - New: MyTaiwanStockTests/ShareImport/PendingImportStoreTests.swift
  - New: MyTaiwanStockTests/ShareImport/PendingImportCoordinatorTests.swift
  - New: MyTaiwanStockTests/TradeImportFlowTests.swift
  - Modified: MyTaiwanStock.xcodeproj/project.pbxproj
  - Modified: MyTaiwanStock/StockList/TradeImportFlow.swift
  - Modified: MyTaiwanStock/StockList/StockListCoordinator.swift
  - Modified: MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift
  - Modified: MyTaiwanStock/StockList/ViewController/StockListViewController.swift
  - Modified: MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift
  - Modified: MyTaiwanStock/SceneDelegate.swift
  - Modified: MyTaiwanStockTests/TestStockListViewModel.swift
  - Modified: fastlane/Fastfile
  - Modified: .github/workflows/ci.yml
  - Removed: (none)
