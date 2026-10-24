## Context

現況（2026-10-24 查程式與審查文件，並經 Opus agent 審查修正）：

- 新增紀錄頁的手續費與稅只是即時估算：手續費 = 價格 × 股數 × 折數乘數 × 0.001425，小於 20 就取 20，不取整（畫面會出現 89.77501 元）；稅只在 buyOrSell 為 1 時才算，但呼叫端兩處都寫死 0，所以稅永遠不會被算；估算結果不存入資料庫。新增頁是 Main.storyboard 的 static table（折數滾輪、手續費欄位在其中），`tableView(_:didSelectRowAt:)` 寫死 `indexPath.row == 6` 開啟備註頁；`shouldChangeCharactersIn` 讀的是變更前的文字，且對所有欄位觸發重算。
- 折數乘數預設寫死 0.6，設定頁只預選滾輪、不會更新乘數；折數只有 1 到 10 的整數；設定頁折數以滾輪列索引存在 UserDefaults（鍵 userDefinedFeeDiscount，預設 0，畫面顯示 1 折）。自訂手續費是一個 Double（鍵 userDefinedFeeInDollars），沒有「使用自訂金額」的模式開關，目前只有新增頁滾輪的第三個類別會用它；`double(forKey:)` 沒存過時回傳 0，分不出未設定。設定頁儲存時用 Double 解析；新增頁儲存時用 `Int` 解析，"20.0" 會失敗。
- Core Data 的 `InvestHistory` 只有 amount、date、price、reason、status、stockNo；模型只有單一版本，.xcdatamodeld 內沒有 .xccurrentversion。專案檔中只有主 App 與 MyTaiwanStockTests 兩個 target 編譯這個模型；小工具、Live Activity 與分享 Extension 都沒有使用資料庫。資料庫放在 App Group，`NSPersistentContainer` 預設的自動輕量遷移沒有被關閉。
- iCloud 備份還原：`CoreDataSchemaCompatibilityChecker` 只注入一個目前版本的模型並要求完全相容；`DefaultICloudBackupService.restoreLatestSnapshot` 先把快照的 sqlite、wal、shm 覆蓋到正式資料庫，再重新載入，載入失敗（非已知的 CloudKit 錯誤）會 `fatalError`。既有備份測試全用假的檢查器。
- 賣單以正的股數、status = 1 存入。`OverViewCalculator` 吃包著 NSManagedObject 的 `HistoryCellModel`，持股數把所有紀錄的股數直接相加，買入均價用「買進價金合計 ÷ 持股數」，所以只要有賣單，兩者都錯；`ChartService` 的資產計算（calculateStockNoToAsset2）已經正確處理正負號。`StockViewController` 綁定均價時用 `guard let priceFloat = Float(price) else { return }`，收到非數字字串會直接返回而不更新標籤。`HistoryCellModel.revenueFloat` 解析 "4.85 %" 永遠失敗，損益顏色從未生效。
- iOS 沒有從 Firestore 下載 history 建立本機紀錄的程式；`HistoryOnline` 只用於上傳。登入後把本機資料匯入雲端的路徑是 `AccountViewController` 的 `importLocalDataToOnlineDB`，它呼叫同一個上傳函式。
- 截圖匯入規格明寫不存手續費與稅，也不改 Core Data 或 Firestore 結構；匯入走與手動新增相同的 `saveNewRecord`。券商截圖的展開明細有實際的手續費與交易稅，收合時只有總額。

## Goals / Non-Goals

**Goals:**

- 手續費與稅用同一套純函式計算，結果可測、尾數處理明確。
- 每筆新紀錄存下手續費與稅（選填的整數新台幣），並在上傳時帶到 Firestore；升級後既有資料與備份都能用，且備份還原不會因遷移失敗而毀掉現有資料庫。
- 持股數、買入均價與買進損益在有賣單時正確，並把手續費併入成本。
- 手動新增與截圖匯入都存入手續費與稅，使用者可在存入前修改。

**Non-Goals:**

- 不解析截圖展開明細中的實際手續費與稅（留待另一個變更）。
- 不做可設定的最低手續費、不依日期判斷債券 ETF 免稅期限、不從股票代碼推斷稅率（匯入的預設類型除外）。
- 不為既有紀錄回填，不做紀錄編輯功能，不做賣出端淨損益報表。
- 不處理 Android；不實作 Firestore 下載（目前也沒有）。

## Decisions

### 金額用 Decimal，存整數元，尾數無條件捨去

計算用 `Decimal`。價格先轉成字串再轉 Decimal（Swift 的 `String(Float)` 輸出最短可還原表示，112.55 會得到 "112.55"）；折數是 Double，同樣先轉字串再轉 Decimal，避免 `Decimal(2.8 as Double)` 的 2.79999… 造成整數邊界少 1 元（折數 2.8、價金 1,000,000 時手續費應為 399）。手續費與稅各自無條件捨去到整數元後存入。理由：券商實務多為捨去，專案內真實截圖測試資料可佐證（瑞昱賣 10 股 @757、6 折：手續費算式 6.47 實收 6，稅算式 22.71 實收 22）。替代方案：四捨五入（與截圖不符）、存 Double（累積誤差、顯示 89.77501）。

### 手續費公式與最低

手續費 = 捨去(成交價金 × 0.001425 × 折數 ÷ 10)，折數 10 代表無折扣；再取最低值：股數 ≥ 1000 套用整股最低 20 元，股數 < 1000 套用零股最低 1 元。這是簡化：股數 ≥ 1000 但不是 1000 的倍數（例如 1500）實際上是整股加零股兩張委託，最低手續費應分開算，這裡一律套整股最低，並以測試固定 999、1000、1500 的結果。固定金額模式直接以該金額為手續費，不再套公式與最低值。`FeeCalculator` 的前置條件：價格大於 0 且股數至少 1，否則回傳空值（呼叫端的輸入驗證已經擋下這兩種輸入，這是防呆）。替代方案：沿用「盤中零股 = 固定 1 元」類別（零股最低不是固定 1 元，例如 10 股 @2470 約 35 元）。

### 手續費模式與折數放設定頁，可輸入小數

設定頁新增手續費模式（折數或固定金額），存新鍵 feeMode（字串：discount 或 fixedAmount）；折數改為 0.1 到 10 的數字輸入（最多兩位小數，10 為無折扣），存新鍵 feeDiscount（Double）；固定金額沿用 userDefinedFeeInDollars。這些設定由新的 `FeeSettings` 讀取並提供給計算與預覽：feeMode 不存在時為折數模式（升級前的使用者沒有模式概念，因此一律折數，不會因為曾存過自訂金額而每筆固定收費）；feeDiscount 不存在時，若舊鍵 userDefinedFeeDiscount 存在就換算為「索引 + 1」，否則為 10。`FeeSettings.current()` 是純讀取：每次讀取時依上述規則換算，不寫入任何鍵（因此測試讀取設定不會改到模擬器的設定）；使用者在設定頁儲存之後才會有新鍵，之後新鍵優先。新增紀錄頁不再有折數滾輪，只顯示依設定計算出的手續費，可直接改。發版說明要寫明：從來沒動過折數的使用者，估算折數從寫死的 0.6 變成無折扣。替代方案：在新增頁保留滾輪並加小數列（滾輪不適合輸入 2.8，且與設定頁重複）。

### 稅率以類型選擇，不從代碼推斷

類型：一般股票 0.3%、現股當沖 0.15%、ETF 0.1%、免稅 0%。稅 = 捨去(成交價金 × 稅率)，只對賣出，買進一律為 0。新增紀錄頁在賣出時顯示類型選擇，預設一般股票；截圖匯入的預設類型：股票代碼以 00 開頭為 ETF，其餘為一般股票，使用者可在預覽頁改稅金。買進的稅固定為 0，匯入編輯器不提供買進的稅欄位。替代方案：從代碼自動判斷（債券 ETF 00679B 與特別股 1101B 這類代碼無法可靠分辨）、依日期判斷免稅期限（期限會變，寫死會過期）。

### Core Data 第二版，選填欄位

新增模型版本，`InvestHistory` 新增 `fee`、`tax`，型別 Integer 32，選填、無預設值、不用純量型別（空值代表未知，與 0 區分；產生的屬性型別是 `NSNumber?`）。要同時改三處，少一項第 2 版都可能不是目前版本：在專案檔新增第 2 版模型的檔案參考並加進 version group 的子項、把 version group 的目前版本指向第 2 版、在 .xcdatamodeld 內建立 .xccurrentversion。沿用 `NSPersistentContainer` 預設的自動輕量遷移。只有主 App 與測試 target 編譯這個模型，所以升級影響不到小工具、Live Activity 與分享 Extension（它們不讀資料庫）。遷移測試的第 1 版資料不用 `InvestHistory` 子類別建立，而用 `NSManagedObject(entity:insertInto:)` 加 KVC 寫入，store 選項與正式環境一樣開啟歷史追蹤，測試結束釋放協調器。替代方案：新增另一個實體存費用（多一次關聯查詢，且舊資料沒有對應列要處理）。

### 備份還原先在暫存副本遷移，成功才取代

`CoreDataSchemaCompatibilityChecker` 改為注入「所有已知版本的模型」（從模型資料夾列舉）：快照的模型符合任一版本即相容，都不符合才回報不相容。相容的快照還原前，先複製到暫存位置，用目前模型與自動遷移選項開啟一次（並確認載入成功）；成功才用既有的協調式覆蓋取代正式資料庫，失敗則不取代、回報錯誤。複製時快照的 sqlite、wal、shm 三個檔案都用協調式讀取（沿用 `SQLiteStoreFileSet`，因為快照放在 iCloud 的 ubiquity container，可能還沒下載完成）；開啟成功後先從暫存的協調器移除儲存庫（關閉 SQLite 連線）再刪除暫存檔；一次協調讀取同時複製兩份：一份用來做相容檢查與遷移驗證，另一份保持原樣；覆蓋正式資料庫時用保持原樣的那一份，不再重讀 iCloud 上的檔案（避免期間另一台裝置寫入新備份，換成沒驗證過的檔案），也不用遷移過的副本；缺少 wal 或 shm 時跳過，與現有覆蓋的處理一致；還原成功或失敗，兩份暫存副本都要刪除。`FileCoordinating` 協定新增協調讀取，`BackupDestinationTests` 的假協調器一併更新。相容檢查（`metadataForPersistentStore`）改在驗證用的暫存副本上執行，不讀 iCloud 原檔。替代方案：維持完全相容檢查（升級後所有舊備份無法還原）、先覆蓋再遷移（遷移失敗會讓正式資料庫損毀，且 App 每次啟動都會在載入時 `fatalError`）。

### Firestore 只在上傳時帶選填欄位

`HistoryOnline` 新增選填的 fee 與 tax（空值時不編碼，合成的 Codable 在 nil 時省略鍵）；上傳函式新增 fee、tax 參數，登入後匯入本機資料的路徑也要從紀錄帶上。不做下載（目前沒有這條路徑）。未來平台拆分、不即時同步由使用者另行決定，不在這個變更。

### 成本、持股與損益的算法

`OverViewCalculator` 改成吃純值（買賣方向、股數、價格、手續費，手續費可為空值），由 `HistoryCellModel` 轉換提供，方便測試。價格從 Core Data 的 Float 先經 `String(Float)` 轉成 Decimal，價金、手續費合計、除法與四捨五入全部用 Decimal（用 Float 計算時 100.145 會變成 100.14）。

- 持股數 = 買進股數合計 − 賣出股數合計；可為負數（例如只有賣單），顯示原值，市值只在持股大於 0 時計算，否則顯示「-」。
- 買入均價（含費用）= (買進價金合計 + 買進手續費合計) ÷ 買進股數合計；未知的手續費視為 0；沒有買單時為空值。
- 賣出均價 = 賣出價金合計 ÷ 賣出股數合計，不含費用；沒有賣單時為空值。
- 買進紀錄的損益% = (現價 − 含費單價) ÷ 含費單價 × 100，含費單價 = (價金 + 手續費) ÷ 股數；賣出紀錄維持「N/A」。`HistoryCellModel` 另外保存數值，損益顏色由數值判斷（取代解析 "4.85 %" 字串）。
- 顯示：均價以小數兩位的字串提供，進位用四捨五入（Decimal 的 plain 模式，例如 100.145 顯示 100.15），空值顯示「-」；view model 直接送出已格式化的字串，`StockViewController` 的綁定改為直接設定標籤文字，不再用 `Float(price)` 的 guard（否則「-」會讓標籤停在舊值）。
- 有任何買進紀錄的手續費未知時，詳情頁在均價旁標示「部分紀錄沒有手續費資料」。
- `StockDetailViewModel.calOverView` 一律送出已格式化的字串：均價與市值為空值時送出「-」，標籤才不會停在舊值（目前市值為空值時什麼都不送）。
- 紀錄列：`StockViewController` 的固定列高 70 改為自動高度並設定預估高度，列內 label 改用 `preferredFont` 並開啟 `adjustsFontForContentSizeCategory`，手續費與稅放在第二行，第二行的 label 文字自帶名稱（例如「手續費 142・稅 0」），表頭維持不變。

這是簡化的整體均價，不是券商的庫存成本（先進先出或移動平均），不在這次範圍。

### 新增頁的計算時機與手動修改

手續費與稅欄位只放數字（單位用旁邊的標籤顯示，不放進欄位文字）。價格或股數欄位每次變更（`editingChanged`，取欄位的最終文字）、切換買賣、改變稅率類型時重新計算。使用者在手續費或稅欄位手動輸入後，該欄位視為手動，之後改價格、股數、方向都不再覆蓋它。欄位被刪空時先保持空白，讓使用者可以重新輸入（不會馬上補回計算值）；使用者離開欄位（`editingDidEnd`）時若仍是空白，就恢復計算值並回到自動。新增的紀錄一律存數字（計算值或使用者輸入），「未知」只屬於升級前的舊紀錄。儲存時以欄位文字為準。買進時不顯示稅的列：static table 不能動態增減列，所以把該列的高度設為 0 並隱藏內容。view model 提供 `didChange(priceText:amountText:)` 之類的入口與可注入的儲存庫（目前寫死 `NetworkServiceImpl()`），讓逐字輸入與存入值能在單元測試驗證。因為新增頁是 static table 的 storyboard，移除折數滾輪那一列並加入稅相關列後，備註列的索引會改變，所以 `didSelectRowAt` 改依 cell 或 outlet 判斷，不再用固定索引。

### 輸入驗證補強

股數上限 32767（`InvestHistory.amount` 為 Int16），超過時回報輸入錯誤而不是閃退；固定手續費改用 Decimal 解析，要求非負，捨去到整數元（"20.5" 得 20），設定頁的 `EditFeeViewController` 也改用同一個驗證並在失敗時顯示錯誤；手續費與稅欄位離開時仍是空白，就恢復計算值；負數、非數字或超過 Int32 範圍視為無效。折數最多兩位小數，超過（例如 2.855）視為無效。decimalPad 在用逗號當小數點的地區會輸入 ","，這是既有行為，台灣地區不受影響，不處理。

### 截圖匯入存估算值，編輯後重新估算

預覽建立時用相同的 `FeeCalculator` 與注入的 `FeeSettings` 為每筆估算手續費與稅（`TradeImportViewModel` 的 init 新增有預設值的 `FeeSettings` 參數，預設讀目前設定；建立它的 `TradeImportFlow.makeStoredViewModel`、`TradeImportFlowTests` 與 `ResizableLayoutTests` 不需要改，結果取決於設定的測試（`TradeImportViewModelTests`、`DefaultTradeImportStoreTests`）一律注入固定的 `FeeSettings`）。預覽列顯示，`TradeEditViewController` 可修改或清空；使用者在編輯器改了股號、價格、股數或方向，而手續費或稅沒有手動改過時，會重新估算。欄位清空後離開時回到估算值，不產生未知的新紀錄。手續費或稅無效時該筆為不完整。估算是預覽時的值，存入後不再重算。替代方案：只在建立時估算一次（補上缺漏的價格、改方向或股號後會與實際不符）、匯入時不存（與「要存」的決定不符）、直接解析展開明細的實際值（收合畫面沒有每筆數字，仍需估算；留待下一個變更）。

## Implementation Contract

**Behavior:**

- 設定頁：可選手續費模式（折數或固定金額），折數可輸入小數，固定金額驗證後存入。
- 新增紀錄頁：輸入價格與股數後，手續費欄位依最終輸入內容立即更新；賣出時多出稅欄位與稅率類型選擇；兩個欄位都可改且手動修改後不被覆蓋，刪空後離開欄位會恢復計算值；按儲存後紀錄帶著手續費與稅存入本機，並在登入狀態下上傳 Firestore。
- 股票詳情頁：持股數與買入均價在有賣單時正確；買入均價含手續費並標示；買進紀錄的損益含手續費且顏色生效；紀錄列表顯示每筆的手續費與稅，未知時顯示「-」。
- 截圖匯入：預覽每列顯示估算的手續費與稅，可修改，編輯後會重新估算；確認後存入。
- 升級後：既有紀錄全部保留，手續費與稅為空值；舊版 iCloud 備份仍可還原，且還原失敗不會毀掉現有資料。

**Interface / data shape:**

- `FeeSettings`：模式（折數 Decimal 或固定金額 Int）；`FeeSettings.current(userDefaults: UserDefaults = .standard)` 純讀取（含舊鍵換算），測試注入 `UserDefaults(suiteName:)`；也可直接建構以供測試注入。
- `FeeCalculator.calculate(price: Decimal, shares: Int, side: TradeSide, settings: FeeSettings, taxCategory: TaxCategory) -> FeeAndTax?`，`FeeAndTax` 含 fee 與 tax（Int）；無效輸入回傳空值。
- `TaxCategory`：stock、dayTrade、etf、exempt，各帶稅率。
- `InvestHistory`：新增 fee、tax（Integer 32，選填，型別 `NSNumber?`）。
- `HistoryOnline`：新增 fee、tax（Int，選填）。
- `NetworkService.saveNewRecord` 與 `OnlineDBUploading.uploadHistoryToOnlineDB` 新增 fee、tax 參數；`TradeImportStore.saveRecord` 新增 fee、tax 參數。測試目標內實作這些協定的 `MockNetworkService`、`MockOnlineDBSyncing` 與 `AccountViewControllerImportTests` 的 mock 要一起更新。
- 備份：相容檢查器注入 `knownModels: () -> [NSManagedObjectModel]`；還原前的遷移檢查可注入，失敗時拋出錯誤且不取代資料庫。
- UserDefaults：新增 feeMode（字串）、feeDiscount（Double）；沿用 userDefinedFeeInDollars（Double）；舊鍵 userDefinedFeeDiscount 只在新鍵不存在時讀取來換算，從不寫入或刪除。

**Failure modes:**

- 股數超過 32767：顯示輸入錯誤，不寫入。
- 固定手續費、手續費欄位或稅欄位格式不合法：顯示輸入錯誤，不寫入（設定頁不儲存）。
- 備份快照為未知版本：回報不相容，不還原。
- 備份快照遷移失敗：回報錯誤，不取代現有資料庫。
- 正式資料庫升級遷移失敗：與目前載入失敗的處理一致（不新增處理）；遷移有單元測試把關。
- 沒有買單：均價為空值，顯示「-」，不除以零。
- 只有賣單或賣多於買：持股為負數照實顯示，市值顯示「-」。

**Acceptance criteria:**

- `FeeCalculatorTests` 涵蓋：規格範例表的 8 個案例；折數 2.8、價金 1,000,000 得 399；價格 112.55 經字串轉換；固定金額模式；股數 999、1000、1500 的最低值；價格 0 或股數 0 回傳空值。
- `FeeSettingsTests` 涵蓋：沒有任何鍵時為折數模式、折數 10；舊索引 5 換算為 6 且不寫入新鍵；折數 2.855 被拒絕；存過固定金額但模式為折數時用公式；輸入 2.8 保留；輸入 0 與 11 被拒絕。
- `OverViewCalculator` 測試涵蓋：買 1000 賣 400 持股 600；買 1000 @100 賣 1000 @105 持股 0；只有賣單時持股為負、均價為空值（修正前回傳 0）；含費用買入均價；損益顏色由數值判斷。
- 遷移測試：用第一版模型建立含 3 筆買單 2 筆賣單的資料庫，以目前模型開啟後紀錄完整、手續費與稅為空值；建置後執行 plutil -p 檢查產物 MyTaiwanStock.app/MyTaiwanStock.momd/VersionInfo.plist（在 DerivedData 的 Build/Products 底下），NSManagedObjectModel_CurrentVersionName 是 "MyTaiwanStock 2"；新增的測試檔都要加進 MyTaiwanStockTests target，並在測試報告看得到測試名稱。
- 備份測試：真實檢查器接受第一版快照、拒絕不同模型建的快照；暫存遷移成功才取代、失敗時正式資料庫不變。
- 輸入驗證測試：股數 32768 回報錯誤而不是崩潰；固定手續費 "20.5" 得 20、"abc" 丟錯。
- 新增頁視圖模型測試：逐字輸入 "1000" 後手續費等於最終字串的計算結果；賣出時稅依所選類型計算；手動修改後改價格不覆蓋；刪光後輸入 50 存入 50；離開時仍是空白就恢復計算值。
- 上傳測試：編碼有值時含 fee 與 tax，空值時沒有這兩個鍵；登入後匯入本機資料時帶出 fee 與 tax。
- 完整單元測試（含更新後的 mock）可編譯並通過；ShareExtension、StockWidgetExtension、LiveActivityExtension 照 CI 方式仍可建置。
- 手動：在 iPhone 17 Pro 與 iPhone Duo 模擬器，以升級前的資料升級後確認資料保留；新增買單與賣單確認顯示與儲存；匯入截圖確認預覽顯示、編輯後重新估算並存入；還原舊備份；紀錄列表在最大 Dynamic Type 字級下不被截斷。

**Scope boundaries:**

- 範圍內：計算函式與設定、資料欄位與遷移、Firestore 上傳欄位、備份還原相容與安全還原、手動新增頁、設定頁手續費模式與折數、持股成本與損益顯示、截圖匯入的估算與預覽、死碼清理、對應測試與規格。
- 範圍外：解析截圖的實際手續費與稅、紀錄編輯、庫存成本的先進先出或移動平均、可設定的最低手續費、Android 與 Firestore 下載、為舊紀錄回填。

## Risks / Trade-offs

- [Core Data 升版後舊版 App 讀不到資料庫] → 只發 TestFlight、不回退；遷移與備份還原都有測試，手動驗證用升級前的真實資料。
- [備份還原放寬相容檢查後遷移失敗] → 先在暫存副本遷移，成功才取代；失敗不動現有資料庫。
- [匯入的估算與券商實際值有差] → 預覽顯示並可修改，這次不解析實際值；規格與設計都標明是估算。
- [簡化的整體均價與券商庫存成本不同] → 明確寫在規格，標題標示「含費用」，不宣稱與券商一致。
- [升級後估算折數預設從 0.6 變成無折扣] → 只影響之後的估算，不影響已存資料；發版說明註明。
- [拿掉新增頁折數滾輪與調整列索引，可能影響 storyboard 與 iPhone Duo 版面] → 紀錄列把手續費與稅放第二行，手動檢查最大 Dynamic Type 與 Duo。
