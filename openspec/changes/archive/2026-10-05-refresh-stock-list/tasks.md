## 1. 準備

- [x] 1.1 從最新的 mvvm 切出分支 feature/1.21/refresh-stock-list（本變更先於 import-trades-from-screenshot 合併，不需要等它），驗證：git branch --show-current 顯示該分支名稱。
- [x] 1.2 若 mvvm 上的 MARKETING_VERSION 仍是 1.20，把 App、StockWidget、LiveActivity 三個 target 原本是 1.20 的 6 處改為 1.21（不動測試 target 的 1.0 共 2 處），單獨 commit；已是 1.21 則略過，驗證：grep MARKETING_VERSION 顯示 1.21 共 6 處、1.0 共 2 處。
- [x] 1.3 若 mvvm 上的 IPHONEOS_DEPLOYMENT_TARGET 尚未全部為 18.0，把所有 target 改為 18.0，單獨 commit；已是 18.0 則略過，驗證：grep IPHONEOS_DEPLOYMENT_TARGET 的每一處都是 18.0，且 xcodebuild build 通過。
- [x] 1.4 實作「清單改為由官方開放資料產生並可更新」的產生腳本 scripts/generate_stock_list.py：從證交所 STOCK_DAY_ALL 與櫃買中心 tpex_mainboard_daily_close_quotes 抓資料，依過濾規則輸出 MyTaiwanStock/Resources/StockList.json（每筆含 code、name、market），驗證：執行腳本後 tse 筆數大於 1,300、otc 筆數介於 1,000 到 1,100，包含 6488、00929、00981A，且不含任何前兩碼為 70 到 73 的 6 碼代號。

## 2. 清單資料與載入（Build the list from official open data、Load the list from cache with a bundled fallback、Provide search strings for adding stocks）

- [x] 2.1 先寫 StockListFilteringTests（修改前會失敗）：「以 StockListEntry 描述股票並過濾上櫃權證」，涵蓋 710000、700019、73000U、72400U 被排除，6488、00679B、006201、00411A 被保留為 otc，同代號兩來源並存時保留 tse，驗證：執行並確認先失敗。
- [x] 2.2 實作 StockListEntry 與官方資料的解析與過濾（Build the list from official open data），櫃買中心回應只解碼代號與名稱兩個欄位，驗證：2.1 測試全部通過，且過濾規則範例表格五列都有對應斷言。
- [x] 2.3 先寫 StockListRepositoryTests（修改前會失敗）：快取有效時使用快取，快取不存在、損毀或為空時使用內建備援，清單永不為空，搜尋字串包含「6488 環球晶」，market(forCode:) 對 6488 回傳 otc，contains(code:) 對 6488 為真、對 23 為假，驗證：執行並確認先失敗。
- [x] 2.4 實作 StockListRepository，即「清單載入順序為本機快取，其次內建備援」（Load the list from cache with a bundled fallback），並提供「代號 名稱」搜尋字串（Provide search strings for adding stocks）；內容只在 main actor 上讀寫；此時保留 MyTaiwanStock/Model/StockNoList.swift 不動，驗證：2.3 測試通過，專案可編譯。
- [x] 2.5 先寫測試（修改前會失敗）：AddStockNoViewModel 的搜尋改讀 StockListRepository，輸入「環球」時結果包含「6488 環球晶」，驗證：執行並確認先失敗。
- [x] 2.6 讓 AddStockNoViewModel 改讀 StockListRepository 的搜尋字串，驗證：2.5 測試通過，在模擬器的新增股票搜尋輸入「環球」可以看到 6488 環球晶。

## 3. 背景更新（Refresh the list in the background when stale、Protect the list from bad refresh results、Run at most one refresh at a time）

- [x] 3.1 先寫 StockListRefresherTests（修改前會失敗，抓取器、快取與時鐘皆注入）：上次成功 6 天前不更新、7 天更新、沒有快取立即更新；上櫃抓回 700 筆（低於 1,007 的 80%，即 805.6）時不採用上櫃、上市照常更新；逾時、HTTP 錯誤、解析失敗時保留舊資料且不記錄時間；同時呼叫兩次 refreshIfNeeded 只抓取一次；更新成功後 StockListRepository 立即回傳新清單，驗證：執行並確認先失敗。
- [x] 3.2 實作 StockListRefresher，即「更新策略為過期才在背景更新，兩個市場獨立防呆」：兩個市場各自套用 80% 防呆，至少一個市場被採用才以原子替換寫入快取並記錄時間（Protect the list from bad refresh results），並以 single-flight 保證同時只有一個更新（Run at most one refresh at a time），在 main actor 上替換 repository 內容，驗證：3.1 測試全部通過，且 Protect the list from bad refresh results 的防呆範例表格四列都有對應斷言。
- [x] 3.3 在 SceneDelegate 的 sceneDidBecomeActive 呼叫更新檢查（Refresh the list in the background when stale），且只在這一處觸發，在背景執行不阻塞畫面，驗證：在模擬器關閉網路後開啟 app，畫面正常且清單仍可搜尋；開啟網路後回到前景，Xcode console 出現一行「stock list refreshed: tse=N otc=M」（N 大於 1,300、M 介於 1,000 到 1,100）；冷啟動時該行只出現一次。

## 4. 輸入驗證（Validate stock numbers by exact match）

- [x] 4.1 先寫會失敗的測試到 MyTaiwanStockTests/ValidInputServiceTest.swift：「輸入驗證改為代號精確比對」，輸入 23 應被拒絕、2330 與 6488 通過、空字串被拒絕，並先執行確認 23 的案例在修正前失敗（目前會通過），驗證：該測試先失敗。
- [x] 4.2 實作 Validate stock numbers by exact match 需求：validStockNo 改為代號必須等於 StockListRepository 內某筆的 code，驗證：4.1 的測試與同檔案的其他測試全部通過。

## 5. 上櫃報價與小工具（Query quotes with the market prefix、Share the market lookup with the widget）

- [x] 5.1 先寫 StockMarketLookupTests（修改前會失敗）：6488 為 otc、2330 為 tse、未知代號為 tse；組出的查詢字串為 otc_6488.tw|tse_2330.tw；兩條報價路徑（fetchOneDayStockInfoCombine 與 TWSEStockInfoFetcher.fetchOneDayStockInfo）組出的 ex_ch 一致，驗證：執行並確認先失敗。
- [x] 5.2 實作 StockMarketLookup（只依賴 Foundation）與「報價查詢依市場決定前綴」：NetworkServiceImpl.fetchOneDayStockInfoCombine 與 TWSEStockInfoFetcher.fetchOneDayStockInfo 兩條路徑都改為依市場組 ex_ch（Query quotes with the market prefix），驗證：5.1 測試通過，模擬器新增 6488 環球晶後首頁出現報價，且 Live Activity 隨主 app 更新顯示該報價。
- [x] 5.3 實作「市場對照透過 App Group 與小工具共用」：載入快取、載入備援或更新成功後，若內容與上次不同才把代號對 market 的字典寫入 App Group 容器的 StockMarkets.json，小工具讀不到時一律預設 tse_（Share the market lookup with the widget），驗證：StockMarketLookupTests 新增案例，以暫存目錄確認檔案寫出與讀入、內容相同時不重寫、檔案不存在時回傳 tse；小工具 target 可編譯。

## 6. K 線資料不足（Show no data when candle data is unavailable）

- [x] 6.1 先寫 ChartServiceTests（修改前會崩潰）：K 線 0 筆、3 筆、8 筆、9 筆呼叫 ChartService 的圖表準備流程都不崩潰，10 筆以上行為不變，並先執行確認 3 筆與 8 筆的案例在修正前崩潰，驗證：該測試先崩潰或失敗。
- [x] 6.2 實作「上櫃股票 K 線無資料時顯示無資料」：ChartService 的 calculateAverageEntries 在筆數不足時回傳空陣列、generateBarData 不再強制解包，StockDetailViewModel 在沒有資料時圖表區顯示無資料（Show no data when candle data is unavailable），驗證：6.1 測試全部通過；模擬器開啟 6488 詳細頁，K 線區顯示無資料，買賣紀錄與概覽正常。

## 7. 收尾與整體驗證

- [x] 7.1 確認已沒有任何程式碼引用 stockNoList（grep 結果為零），再移除 MyTaiwanStock/Model/StockNoList.swift，驗證：grep stockNoList 沒有結果，xcodebuild build 通過。
- [x] 7.2 把新增檔案、StockList.json 資源與 StockMarketLookup 的小工具 target 成員資格加入 MyTaiwanStock.xcodeproj/project.pbxproj，驗證：xcodebuild build 與 test 通過，CI 的 build-and-test 可編譯。
- [x] 7.3 端到端驗證：在模擬器新增 6488 環球晶與 00929，首頁、小工具與 Live Activity 顯示報價；執行整個 MyTaiwanStockTests 全部通過；git diff 不含 xcdatamodeld（沒有改 Core Data schema）。
- [ ] 7.4 驗證 Android：在 iPhone 把 6488 加入清單並確認已同步到 Firestore，開啟 Android app，記錄 6488 是否出現、有無報價、有無異常（崩潰或空白列），驗證：結論寫入 design.md 的 Risks；若有問題，在 PR 說明列為已知限制。
