## 1. 準備

- [x] 1.1 從 refresh-stock-list 分支切出分支 feature/1.21/import-trades-from-screenshot（疊在 refresh 分支上，這是對「合併後才切新分支」規則的例外，PR 要標明相依；refresh 以 Merge commit 合併進 mvvm 後，再把 mvvm 合併進本分支），驗證：git branch --show-current 顯示該分支名稱，且 git log 含 StockListRepository 的 commit。
- [x] 1.2 若 mvvm 上的 MARKETING_VERSION 仍是 1.20，在該分支把 App、StockWidget、LiveActivity 三個 target 原本是 1.20 的 6 處改為 1.21（不動測試 target 的 1.0 共 2 處），單獨 commit；若已是 1.21 則略過，驗證：grep MARKETING_VERSION 顯示 1.21 共 6 處、1.0 共 2 處。
- [x] 1.3 若 mvvm 上的 IPHONEOS_DEPLOYMENT_TARGET 尚未全部為 18.0，在該分支把所有 target 改為 18.0，單獨 commit；已是 18.0 則略過，驗證：grep IPHONEOS_DEPLOYMENT_TARGET 的每一處都是 18.0，且 xcodebuild build 通過。
- [ ] 1.4 取得一張投資先生「現股」成交的截圖（解決 design 的 Open Questions：現股股數欄以股或張顯示），並記錄結論到 design.md 的 Open Questions；若以張顯示，在 spec 與 tasks 補上乘以 1000 的規則，驗證：design.md 的 Open Questions 已有明確結論。
- [x] 1.5 建立測試資料：把樣本截圖（收合的元大台灣50、華邦電；展開的台積電、瑞昱；以及頂部被切掉、含「融資買進」列、含合併文字框的變體）整理成 RecognizedTextBox 清單（文字加標準化座標，採 Vision 的左下原點，y 越大越靠上），放在 MyTaiwanStockTests 內的測試輔助檔，驗證：測試輔助檔可載入，且四筆樣本交易的文字框包含展開區塊的「委託書號」、「手續費」、「交易稅」標籤與摘要列文字。

## 2. 解析器（Parse two-line trade rows by position、Ignore expanded detail block、Restrict scope to supported trade types）

- [x] 2.1 先寫 TradeScreenshotParserTests（修改前會失敗）：收合畫面解析出「元大台灣50 買 5 股 112.55 2026-09-30」與「華邦電 買 3 股 179.5 2026-10-01」；展開畫面解析出「台積電 買 1 股 2470.0 2026-09-22」與「瑞昱 賣 10 股 757.0 2026-09-23」；千分位逗號移除；頂部列被切掉的交易標為不完整且不借用摘要列文字；合併文字框 `09/30 盤中零股買進` 仍可解析，驗證：執行該測試檔，先確認全部失敗。
- [x] 2.2 實作 Parse two-line trade rows by position 需求的 TradeScreenshotParser（純函式，只輸入 RecognizedTextBox，輸出 ParsedTrade）：依「依座標分群成一筆交易，不依文字行順序」，以類型欄文字（以買進或賣出結尾）為錨點，上行必須在錨點上方 0.5 到 2.5 倍文字框高度內並含 `yyyy/` 片段，同一行容差以文字框高度中位數的 0.5 倍計，找不到上行時標為不完整，驗證：2.1 的測試全部通過。
- [x] 2.3 先寫測試（修改前會失敗）：瑞昱展開畫面只產生一筆交易，摘要列與表頭列文字（總應收付、總損益、日期、名稱等）不產生交易，驗證：執行並確認先失敗。
- [x] 2.4 實作 Ignore expanded detail block 需求，即「展開區塊的文字一律忽略」：含展開區塊標籤、摘要列標籤與表頭文字的文字框與同列的值不參與分群，驗證：2.3 的測試通過。
- [x] 2.5 先寫測試（修改前會失敗）：同一批文字框中的「融資買進」列出現且 isSupportedType 為 false，另一筆盤中零股買進仍正常解析；六個支援的類型字串（現股、盤中零股、盤後零股各買進與賣出）isSupportedType 為 true，驗證：執行並確認先失敗。
- [x] 2.6 實作 Restrict scope to supported trade types 需求：以類型字串白名單判斷 isSupportedType，不支援的類型仍產生 ParsedTrade 並不中斷其他筆，驗證：2.5 的測試通過。

## 3. 股名對股號（Resolve stock number from stock name）

- [x] 3.1 先寫 StockNameResolverTests（修改前會失敗，注入固定清單資料）：元大台灣50 對到 0050、華邦電對到 2344、台積電對到 2330、瑞昱對到 2379；清單名稱含空白的 `元大MSCI A股` 可由去除空白的 OCR 文字 `元大MSCIA股` 對上；全形與半形差異可對上；不存在的股名回傳 nil；同名多筆回傳 nil，驗證：執行並確認先失敗。
- [x] 3.2 實作 Resolve stock number from stock name 需求的 StockNameResolver：「以股名精確對照既有股票清單取得股號」，建構時注入 StockListEntry 陣列，兩側都先做 Unicode 相容正規化並移除所有空白後再精確比對，正式環境由 StockListRepository 提供條目，驗證：3.1 測試全部通過，並確認 6488 環球晶可對回代號。

## 4. 文字辨識與選圖（Recognize trades from screenshots on device）

- [x] 4.1 實作 Recognize trades from screenshots on device 需求的 TradeTextRecognizer：「使用 Vision 在裝置端辨識文字，並輸出文字加座標」，recognitionLevel 為 accurate，語言為 zh-Hant 與 en-US，usesLanguageCorrection 為 false，輸出 RecognizedTextBox（Vision 座標，原點左下）；不呼叫任何網路 API，驗證：在模擬器以樣本截圖執行，辨識結果包含「元大台灣50」與「盤中零股買進」，且 grep 該檔案沒有 URLSession 或網址字串。
- [x] 4.2 先寫測試（修改前會失敗）：以無效圖片資料呼叫辨識流程，確認拋出錯誤、不產生任何交易，驗證：執行並確認先失敗。
- [x] 4.3 實作「使用 PHPickerViewController 選圖，辨識在背景執行」：selectionLimit 為 0，圖片載入失敗時顯示錯誤並不寫入任何資料，VNImageRequestHandler 在背景 queue 執行、結果回到 main thread，驗證：4.2 的測試通過，模擬器手動選兩張圖，選圖與辨識期間畫面不卡住。

## 5. 匯入流程與預覽（Mandatory preview with per-trade confirmation、Detect duplicates）

- [x] 5.1 先寫 TradeImportViewModelTests 的預覽案例（修改前會失敗）：可匯入、重複（與既有紀錄、與同批較前面的筆；日曆日以台北時區判定）、不完整（缺股號、價格、股數、日期；股數 0、32768、33000；價格不大於 0）、不支援四種狀態與優先順序（不支援、不完整、重複、可匯入）；重複預設不勾選但可手動勾回；編輯後重新計算狀態並自動勾選或取消勾選；手動輸入不存在於清單的股號仍不可勾選；沒有勾選時匯入為停用，驗證：執行並確認先失敗。
- [x] 5.2 實作 TradeImportViewModel 的預覽邏輯：「預覽頁為必經步驟，並在此完成去重」，去重鍵為股號、台北日曆日、價格、股數、買賣方向，股數範圍 1 到 32767（「股數單位為『股』，直接存入 amount」，不做單位換算），驗證：5.1 測試全部通過，且 Detect duplicates 的四列範例表格與股數驗證範例表格都有對應斷言。
- [x] 5.3 實作 Mandatory preview with per-trade confirmation 需求的 TradeImportPreviewViewController：逐筆顯示勾選框、日期、股號與股名、買或賣、價格、股數與狀態，可編輯五個欄位，不完整與不支援的筆標紅，匯入按鈕在沒有勾選時停用，驗證：模擬器手動操作，確認紅色標示、編輯後狀態重算與按鈕狀態變化。
- [x] 5.4 先寫測試（修改前會失敗）：TradeImportViewModelTests 新增「選擇清單」案例，預設為傳入的目前清單，沒有任何清單時預設為「不加入清單」，選項包含所有清單與「不加入清單」，選「不加入清單」時顯示提示，驗證：執行並確認先失敗。
- [x] 5.5 實作 Choose target list for imported stocks 需求，即「匯入時可選擇加入的清單」：預覽頁頂部加入清單選擇器與提示文字，TradeImportViewModel 提供 selectedList，由 StockListCoordinator 把清單與目前清單傳入，驗證：5.4 測試通過，並在模擬器手動確認選擇器可切換、提示文字只在選「不加入清單」時出現。
- [x] 5.6 實作「入口放在首頁「+」按鈕展開的選單」：保留 FloatingButtonManager，重新設計外觀（毛玻璃膠囊選項加彩色圖示、「+」旋轉成「×」、依序彈出、背景模糊可點擊收起），新增「截圖匯入」與 FloatingButtonManagerDelegate 的 didTapSecondaryButton3；「新增股票」在沒有清單時隱藏且不留空隙；StockListCoordinatorProtocol 新增開啟匯入流程的方法，並在 MyTaiwanStockTests/TestStockListViewModel.swift 的 MockStockListCoordinator 實作，驗證：測試 target 可編譯，模擬器手動操作，展開後出現三個選項、再點一次或點背景可收起，沒有清單時只有兩個選項且無空隙。

## 6. 寫入（Write through the existing record flow、Show imported stocks on the home screen after import）

- [x] 6.1 先寫 TradeImportViewModelTests 的寫入案例（修改前會失敗，使用 XCTest，因為會替換 LocalDBService.shared.container，不可用 Swift Testing，參考 MyTaiwanStockTests/DuplicateStockNoTests.swift）：三筆中勾選兩筆時 saveNewRecord 被呼叫兩次、元大台灣50 存成 stockNo 0050、status 0、amount 5、price 112.55、date 為台北 2026-09-30 12:00:00.000、reason 為空字串；同一天兩筆匯入紀錄的 date 為 12:00:00.000 與 12:00:00.001 且同為台北同一日曆日；與既有紀錄的時間戳撞號時再加 1 毫秒；選取的筆中有一筆股數 33000 時一筆都不寫入並回傳錯誤；手動勾回的重複項會被寫入，驗證：執行並確認先失敗。
- [x] 6.2 實作 Write through the existing record flow 需求的 confirmImport：「寫入前先驗證全部勾選項目，且在主執行緒寫入」，全部合法才在 main actor 逐筆呼叫 NetworkServiceImpl 的 saveNewRecord；「匯入紀錄的時間戳與日曆日規則」，日期為台北時區當日 12:00:00.000 並避免撞號；「寫入沿用 saveNewRecord，不新增寫入路徑」，reason 一律傳空字串，回傳送出筆數；「手續費與交易稅只顯示、不儲存」，不寫入也不新增欄位，驗證：6.1 測試全部通過。
- [x] 6.3 先寫測試（修改前會失敗，XCTest 加 in-memory Core Data）：依 selectedList 加入股票，spec 範例表格三列（0050 與 2344 對含 0050 的清單只加 2344；2379 買賣各一筆只加一次；取消勾選的 2330 不加入）；選「不加入清單」時不動任何清單；匯入兩次後清單內同一股號只有一筆，驗證：執行並確認先失敗。
- [x] 6.4 實作依 selectedList 把匯入的股票加入清單：對實際匯入交易的不重複股號呼叫 NetworkServiceImpl.saveStockNumber，已在清單內者略過，驗證：6.3 測試通過。
- [x] 6.5 實作「預覽頁以 push 進入，匯入後通知首頁重新載入」（Show imported stocks on the home screen after import）：預覽頁 push 到首頁的 navigationController，匯入完成後呼叫 callback，由 StockListViewModel 重新載入目前清單、更新 App Group 的 stockNos 並重新載入小工具時間軸，驗證：模擬器手動操作，匯入完成回到首頁時新股票立即出現，不需切換清單或重開 app。

## 7. 整合與整體驗證

- [x] 7.1 把新增檔案與測試加入 MyTaiwanStock.xcodeproj/project.pbxproj，驗證：xcodebuild build 與 test 通過，且 CI 的 build-and-test 流程可編譯。
- [ ] 7.2 在模擬器端對端執行：放入兩張樣本截圖，完成選圖、預覽、匯入，驗證買賣紀錄列表出現四筆對應紀錄，Firestore 有對應文件；在其中一檔的詳細頁刪除一筆紀錄，確認 Firestore 只少那一筆；再匯入同一張截圖時整批標為重複且預設不勾選。
- [x] 7.3 執行整個 MyTaiwanStockTests，驗證：既有測試與新增測試全部通過，沒有改動既有 Core Data 與 Firestore schema（git diff 不含 xcdatamodeld）。
