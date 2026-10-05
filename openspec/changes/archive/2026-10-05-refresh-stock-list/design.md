## Context

股票代號清單目前是 MyTaiwanStock/Model/StockNoList.swift 內的全域陣列 stockNoList，共 1,120 筆「代號 名稱」字串，最後修改於 2022-03-16。使用處：新增股票搜尋（AddStockNoViewModel 以字串 contains 過濾）、輸入驗證（ValidInputService.validStockNo 同樣用 contains，所以輸入 23 也會通過），目前 validStockNo 在 app 內沒有任何呼叫端。後續的 import-trades-from-screenshot 變更會依賴本變更提供的 StockListRepository（股名對股號與手動輸入股號驗證），因此本變更必須先合併。

報價查詢（NetworkServiceImpl 與 TWSEStockInfoFetcher）把代號寫死成 tse_{code}.tw 後呼叫 mis.twse.com.tw 的 getStockInfo。已實測同一個端點用 otc_6488.tw 可回傳上櫃的環球晶價格，所以報價只要改前綴即可支援上櫃。K 線（fetchCandleData、fetchTwoMonthCandleData）只呼叫 www.twse.com.tw 的 STOCK_DAY，僅支援上市。

TWSEStockInfoFetcher 同時被小工具（StockWidget）使用，且刻意只依賴 Foundation，以控制小工具的記憶體。主 app 與小工具已共用 App Group group.a2006mike.myTaiwanStock。

官方開放資料（2026-10-02 實測）：

- 證交所 https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL：欄位 Code、Name，共 1,380 筆（4 碼 1,094、5 碼 134、6 碼 152），含 ETF 與 ETN；只列當天有成交的證券。
- 櫃買中心 https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes：欄位 SecuritiesCompanyCode、CompanyName，共 11,928 筆，其中 6 碼且前兩碼為 70、71、72、73 的權證約 10,900 筆；保留 4 碼股票與 00 開頭的 ETF 後約 1,007 筆。

## Goals / Non-Goals

**Goals:**

- 清單包含上市、上櫃與 ETF，並能在不發版的情況下自動更新。
- 更新失敗、資料異常時，使用者看到的清單不變，且清單永遠不為空。
- 上櫃股票可新增、可看到報價（主 app、小工具、Live Activity）。
- 清單更新同一時間只會執行一個，且在不同執行緒讀寫清單不會發生 data race。
- 專案最低部署版本改為 iOS 18.0，所有 target 一致。
- 輸入驗證只接受清單內的完整代號。

**Non-Goals:**

- 不支援上櫃股票的 K 線，也不調查櫃買中心歷史資料端點。
- 不經過自己的 server，不上傳任何使用者資料。
- 不修改 Core Data 與 Firestore schema。
- 不修改 Android；上櫃代號同步到 Android 的行為只做確認與記錄。
- 不納入權證與興櫃，不做背景更新（BGTaskScheduler）。

## Decisions

### 清單改為由官方開放資料產生並可更新

採用「裝置直接抓官方開放資料、存本機、失敗退回內建備援」。官方資料不需金鑰，也不經過使用者資料。

替代方案：(a) 發版時用腳本更新內建清單：兩次發版之間仍會過期，保留作為備援的產生方式；(b) 經由自己的 server 定期抓再提供給 app：需要維護家用 ddns server，且目前 server 只負責推播，捨棄。

### 以 StockListEntry 描述股票並過濾上櫃權證

StockListEntry 包含 code、name、market（tse 或 otc）。證交所來源整筆保留，market 為 tse。櫃買中心來源保留「代號長度小於等於 5」或「代號以 00 開頭」者，market 為 otc；其餘（6 碼且不以 00 開頭，即 70、71、72、73 開頭的權證）排除。同一代號在兩個來源都出現時，以證交所為準。

替代方案：改用櫃買中心的上櫃公司基本資料（mopsfin_t187ap03_O，892 筆）：不含上櫃 ETF（如 00679B），捨棄。

### 清單載入順序為本機快取，其次內建備援

StockListRepository 啟動時先讀 Application Support 內的快取 JSON；不存在、無法解析或筆數為零時改讀 app bundle 內的 StockList.json。對外提供：全部 StockListEntry、「代號 名稱」搜尋字串、依代號查詢 market、代號是否存在。內建備援取代硬編碼的 stockNoList，StockNoList.swift 移除。

### 更新策略為過期才在背景更新，兩個市場獨立防呆

StockListRefresher 在啟動與回到前景時檢查：沒有快取，或距上次成功更新達 7 天，才在背景更新，不阻塞畫面。兩個市場各自獨立抓取與判斷：抓回並過濾後的筆數低於「該市場目前筆數的 80%」就不採用該市場；解析失敗、逾時、HTTP 錯誤一律保留該市場的舊資料；至少有一個市場成功採用才寫入新快取並記錄時間，寫入以原子替換（先寫暫存檔再取代）。只有兩個市場都失敗時不記錄時間，下次回到前景再試。

並行規則：StockListRefresher 同時只允許一個更新在執行（single-flight），執行中再次被觸發時直接共用進行中的更新，不再下載一次。觸發點只有 SceneDelegate 的 sceneDidBecomeActive 一處（冷啟動時 scene(_:willConnectTo:) 與 sceneWillEnterForeground 也會被呼叫，不在這兩處觸發）。StockListRepository 的內容只在 main actor 上讀寫；更新成功後在 main actor 上立即替換，之後的讀取（搜尋、驗證、股名對照）立即看到新清單。為了降低流量，櫃買中心的回應只解碼 SecuritiesCompanyCode 與 CompanyName 兩個欄位。

防呆的原因：STOCK_DAY_ALL 只列當天有成交的證券，休市日或資料不完整時筆數會明顯偏少。

替代方案：把新舊清單取聯集以避免遺漏：已下市的代號永遠不會被移除，捨棄。

### 報價查詢依市場決定前綴

組 ex_ch 時，依 StockMarketLookup 查到的 market 使用 tse_{code}.tw 或 otc_{code}.tw；查不到時預設 tse_，與現有行為相容。報價有兩條路徑，兩條都要改：首頁使用的 NetworkServiceImpl.fetchOneDayStockInfoCombine（自己組 ex_ch），以及 NetworkServiceImpl.fetchOneDayStockInfo 呼叫的 TWSEStockInfoFetcher.fetchOneDayStockInfo（小工具也使用）。Live Activity 不自己抓報價，由主 app 的 StockListViewModel 更新，因此隨主 app 的改動自動支援上櫃，不需要讀 App Group 的對照檔。

### 市場對照透過 App Group 與小工具共用

StockMarketLookup 只依賴 Foundation，負責讀寫 App Group 容器內的 StockMarkets.json（代號對 market 的字典）。StockListRepository 每次載入快取、載入備援或更新成功後都寫出這份檔案；小工具的 TWSEStockInfoFetcher 只讀它，讀不到就全部預設 tse_。這樣小工具不需要載入整份清單，也不會增加太多記憶體。

替代方案：小工具自己載入完整清單 JSON：約 2,400 筆，對小工具記憶體預算不划算，捨棄。

### 輸入驗證改為代號精確比對

validStockNo 改為「代號必須等於清單中某一筆的 code」，不再用子字串比對。這是 bug 修正，依專案流程必須先寫會失敗的測試。

### 上櫃股票 K 線無資料時顯示無資料

fetchTwoMonthCandleData 對上櫃代號會回傳空陣列（證交所 STOCK_DAY 查不到，實測回應為「沒有符合條件的資料」，解碼失敗後得到空陣列）。ChartService 的 calculateAverageEntries 在計算 10 日均線時使用範圍 (windowSize - 1)..<count，當筆數少於 9 筆（0 到 8 筆）時範圍的下界大於上界會直接崩潰；generateBarData 也有強制解包。這不只發生在上櫃：新上市不到 9 個交易日的證券（清單每 7 天更新後會搜得到）也會中招。因此修正條件是「筆數少於計算均線所需」而不只是「空資料」：筆數不足時不畫均線，只畫現有的蠟燭與成交量；沒有任何資料時圖表區顯示無資料。K 線對上櫃的實際支援另開變更。

## Implementation Contract

**Behavior:**

- 新增股票的搜尋可以搜到上櫃股票（如 6488 環球晶）與新 ETF（如 00929、00981A）。
- 加入上櫃股票後，首頁列表、小工具與 Live Activity 顯示即時報價。
- 清單在背景自動更新；網路失敗時使用者不會看到錯誤，清單維持原樣。
- validStockNo 對 23 回傳拒絕，對 2330 與 6488 回傳通過（單元測試驗證；目前沒有 UI 入口，後續的截圖匯入預覽頁在手動輸入股號時使用）。
- 上櫃股票或新上市證券（K 線少於 9 筆）的詳細頁不崩潰：沒有資料時 K 線區顯示無資料，資料不足時只畫蠟燭與成交量，頁面其餘部分（買賣紀錄、概覽）正常。
- 清單更新同一時間只會有一個在執行；冷啟動時只觸發一次。

**Interface / data shape:**

- StockListEntry：code（String）、name（String）、market（tse 或 otc）。
- StockListRepository：entries、searchStrings（元素為「代號 名稱」）、market(forCode:)、contains(code:)。
- StockListRefresher.refreshIfNeeded(now:)：依注入的時鐘、抓取器與快取儲存執行；回傳每個市場是「已更新」「略過」或「失敗保留舊資料」。
- StockMarketLookup：market(forCode:) 回傳 tse 或 otc，未知回傳 tse；寫出與讀入 StockMarkets.json。
- 內建備援 MyTaiwanStock/Resources/StockList.json：entries 陣列，每筆含 code、name、market。

**Failure modes:**

- 網路錯誤、逾時、HTTP 非 200、JSON 解析失敗：保留舊資料，不顯示錯誤，不記錄成功時間。
- 抓回筆數低於該市場目前筆數的 80%：不採用該市場，另一個市場照常判斷。
- 快取檔損毀：改讀內建備援。
- 更新進行中又被觸發：共用進行中的更新，不重複下載。
- App Group 容器無法寫入：略過共享，小工具預設 tse_，不影響主 app。

**Acceptance criteria:**

- StockListFilteringTests：權證代號 710000、700019、73000U、72400U 被排除；6488、00679B、006201、00411A 被保留；同代號在兩個來源出現時以證交所為準。
- StockListRepositoryTests：快取有效時使用快取；快取不存在或損毀時使用內建備援；清單永不為空；搜尋字串含「6488 環球晶」。
- StockListRefresherTests：上次成功 6 天前不更新、7 天更新、沒有快取立即更新；上櫃抓回 700 筆（低於 1,007 的 80%，即 805.6）時不採用上櫃、上市照常更新；錯誤時保留舊資料且不記錄時間；同時呼叫兩次 refreshIfNeeded 只會抓取一次。
- ValidInputServiceTest：23 拒絕、2330 通過、6488 通過、空字串拒絕（修正前先確認 23 會通過而失敗）。
- ChartServiceTests：K 線 0 筆、3 筆、8 筆都不崩潰（修正前先確認會崩潰），9 筆以上行為不變。
- StockMarketLookupTests：查詢 6488 為 otc、2330 為 tse、未知代號為 tse；組出的 ex_ch 為 otc_6488.tw|tse_2330.tw。
- 手動驗證：模擬器新增 6488 環球晶與 00929，首頁出現報價；開啟 6488 詳細頁 K 線區顯示無資料且不崩潰；關閉網路後重新開啟 app，清單仍可搜尋。

**Scope boundaries:**

- In scope：清單來源與過濾、本機快取與內建備援、過期更新與防呆、報價前綴、小工具市場對照、輸入驗證修正、上櫃 K 線無資料不崩潰。
- Out of scope：上櫃 K 線、自家 server、Core Data 與 Firestore schema、權證與興櫃、BGTaskScheduler 背景更新、清單的使用者介面（例如手動更新按鈕）。

## Risks / Trade-offs

- [官方開放資料的欄位或網址改版] → 解析失敗時保留舊資料，內建備援仍可用；改版時更新解析器與腳本。
- [STOCK_DAY_ALL 只列當天有成交的證券，筆數偏少] → 80% 防呆，低於門檻不採用。
- [上櫃來源的權證過濾規則漏掉新型態商品] → 規則以代號長度與 00 開頭為準，新增型態商品時筆數會異常增加，測試與防呆能提早發現；可再收緊規則。
- [已下市股票仍在使用者的追蹤清單] → 清單只用於搜尋與驗證，不影響已追蹤的股票；報價查不到時沿用現有行為。
- [小工具讀不到 StockMarkets.json，把上櫃股票當上市查詢，查無報價] → 預設 tse_ 與現行行為相同，主 app 開啟後即會寫出對照檔。
- [與 import-trades-from-screenshot 的相依] → 本變更先合併，import 變更再從最新 mvvm 切出分支，直接使用 StockListRepository。
- [上櫃代號同步到 Android，Android 的前綴與驗證行為未知] → 任務中在 Android 實測 6488，記錄結果；若有問題列為已知限制並另案處理，不在本變更內修改 Android。
- [停牌的股票在更新後從清單消失] → 清單只用於搜尋、驗證與股名對照，已追蹤的股票不受影響；停牌股票下次有成交時會重新出現，這是接受的行為。
- [把 StockMarkets.json 每次都重寫浪費 I/O] → 只在內容與上次不同時才寫入。
