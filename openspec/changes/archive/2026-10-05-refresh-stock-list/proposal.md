## Why

app 的股票代號清單是硬編碼在原始碼裡的 1,120 筆字串，最後一次修改是 2022-03-16。對照證交所 2026-10-02 的資料，清單缺 301 個代號（例如新上市的 ETF 00929、00981A、00400A），另有 23 個已下市或合併的代號還在清單裡，而且完全沒有上櫃股票（例如 6488 環球晶）。使用者因此加不進新的 ETF 與上櫃股票，之後的「截圖匯入」（import-trades-from-screenshot）也會對不上這些股名，所以本變更是它的前置變更。清單需要能自動更新，並納入上櫃股票。

## What Changes

- 清單改由官方開放資料產生：上市與 ETF 取自證交所 STOCK_DAY_ALL，上櫃取自櫃買中心 tpex_mainboard_daily_close_quotes；上櫃資料裡的權證（6 碼且不以 00 開頭的代號）一律排除。
- 清單資料模型改為 StockListEntry（代號、名稱、市場 tse 或 otc），以 JSON 存在本機；app 內建一份備援 JSON（由腳本從兩個來源產生），取代硬編碼的字串陣列。
- app 啟動或回到前景時，若距上次成功更新已達 7 天或沒有快取，就在背景更新清單，不阻塞畫面。兩個市場各自獨立更新，抓回筆數低於該市場目前筆數 80% 就不採用；任何失敗都保留舊資料。
- 報價查詢依市場決定前綴：上市用 tse_，上櫃用 otc_，查不到市場時預設 tse_。主 app 與小工具共用同一份市場對照（透過 App Group 共享）；Live Activity 由主 app 的報價更新，因此自動支援上櫃。
- validStockNo 由子字串比對改為代號精確比對（輸入 23 目前也會通過）。這個驗證目前在 app 內沒有任何呼叫端，屬於潛在問題；改完後由後續的截圖匯入預覽頁在手動輸入股號時使用。
- 專案最低部署版本改為 iOS 18.0（App、小工具、Live Activity 與測試 target 一致）。
- 清單更新同一時間只會有一個在執行；K 線資料少於計算均線所需筆數（含新上市的證券）時不再崩潰。
- 上櫃股票的詳細頁在 K 線取不到資料時不崩潰，顯示無資料。
- 新增股票的搜尋仍以「代號 名稱」字串做 contains 比對，行為不變，資料來源改為新的清單。

## Non-Goals

- 不支援上櫃股票的 K 線：K 線目前只呼叫證交所 STOCK_DAY，僅支援上市；櫃買中心歷史資料端點（st43_result.php）實測回傳的不是 JSON，需另行調查，另開變更處理。
- 不經過自己的 server：清單由裝置直接連官方開放資料，不需金鑰，不上傳任何使用者資料。
- 不修改 Core Data 與 Firestore schema：買賣紀錄與清單仍只存股號。但上櫃代號會透過 Firestore 同步到 Android 的清單，Android 的行為尚未驗證，列為任務確認，結論不在本變更內處理。
- 不納入權證、興櫃與其他未有報價支援的商品。
- 不做背景更新（BGTaskScheduler）：只在啟動與回到前景時檢查。

## Capabilities

### New Capabilities

- `stock-list-refresh`: 股票代號清單的來源、過濾規則、本機快取與內建備援、定期背景更新與防呆，以及代號精確驗證與搜尋字串。
- `otc-stock-support`: 依市場決定報價前綴、與小工具共享市場對照，以及上櫃股票 K 線無資料時的畫面行為。

### Modified Capabilities

(none)

## Impact

- Affected specs: 新增 `stock-list-refresh`、`otc-stock-support`；是 `import-trades-from-screenshot` 的前置變更（該變更的股名對股號與股號驗證讀取本變更的 StockListRepository），必須先合併。
- Affected code:
  - New: scripts/generate_stock_list.py（從兩個官方來源產生內建備援 JSON）
  - New: MyTaiwanStock/Resources/StockList.json（內建備援清單）
  - New: MyTaiwanStock/Model/StockListEntry.swift
  - New: MyTaiwanStock/Util/StockListRepository.swift（載入快取或備援、提供搜尋字串與市場查詢）
  - New: MyTaiwanStock/Util/StockListRefresher.swift（過期判斷、抓取、防呆、原子替換）
  - New: MyTaiwanStock/Util/StockMarketLookup.swift（只依賴 Foundation，主 app 與小工具共用）
  - New: MyTaiwanStockTests/StockListFilteringTests.swift
  - New: MyTaiwanStockTests/StockListRepositoryTests.swift
  - New: MyTaiwanStockTests/StockListRefresherTests.swift
  - New: MyTaiwanStockTests/StockMarketLookupTests.swift
  - Modified: MyTaiwanStock/View Controller/View Model/AddStockNoViewModel.swift（搜尋改讀新的清單）
  - Modified: MyTaiwanStock/Util/ValidInputService.swift（代號精確比對）
  - Modified: MyTaiwanStockTests/ValidInputServiceTest.swift（新增精確比對的測試）
  - Modified: MyTaiwanStock/Repository/NetworkServiceImpl.swift（依市場組報價前綴）
  - Modified: MyTaiwanStock/Repository/TWSEStockInfoFetcher.swift（依市場組報價前綴，供小工具使用）
  - Modified: MyTaiwanStock/SceneDelegate.swift（啟動與回到前景時觸發更新檢查）
  - Modified: MyTaiwanStock/View Controller/View Model/StockDetailViewModel.swift（K 線無資料時不崩潰）
  - Modified: MyTaiwanStock/Util/ChartService.swift（資料少於均線所需筆數時不崩潰）
  - New: MyTaiwanStockTests/ChartServiceTests.swift
  - Modified: MyTaiwanStock.xcodeproj/project.pbxproj（加入新檔案、JSON 資源，並讓小工具 target 包含 StockMarketLookup）
  - Removed: MyTaiwanStock/Model/StockNoList.swift（硬編碼清單）
- Dependencies: 不新增第三方套件；使用既有 App Group（group.a2006mike.myTaiwanStock）共享市場對照。
