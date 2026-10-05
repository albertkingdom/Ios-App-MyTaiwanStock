## Why

使用者的實際交易發生在元大證券「投資先生」app，但這個 app 的買賣紀錄只能逐筆手動輸入，容易漏記、輸錯。投資先生沒有匯出成交明細的功能（無 CSV、Excel、PDF），也沒有開放第三方讀取個人成交資料的 API，唯一能取得資料的管道是「交易 → 明細」畫面本身，因此改用截圖辨識（OCR）把畫面上的成交明細轉成買賣紀錄。

## What Changes

- 在首頁右下角的「+」按鈕展開後，新增「截圖匯入」選項，作為「從截圖匯入」流程的入口：使用者以系統照片選取器（PHPickerViewController，不需要相簿權限）選取一張或多張投資先生明細頁截圖，app 以裝置端 OCR 辨識文字，解析出每筆成交，經預覽頁逐筆確認後寫入既有買賣紀錄。
- 新增截圖解析器：依文字框座標將畫面分群為「一筆交易」並分欄，辨識股名、買賣方向、價格、股數、日期；收合與展開兩種畫面皆須能解析，展開區塊的明細文字一律忽略。
- 股名對回股號：投資先生畫面只顯示股名，不顯示股號，以 refresh-stock-list 變更提供的股票清單（StockListRepository）把股名對回股號；對不上的筆標紅，由使用者手動輸入股號，輸入值必須與清單內某個代號完全相等。
- 新增匯入預覽頁：逐筆顯示、可編輯、可取消勾選；辨識不完整的筆（含股數不在 1 到 32767、價格不大於 0）不可勾選直到補完；重複的筆預設不勾選但可手動勾回。預覽頁為必經步驟，不提供直接匯入。
- 預覽頁頂部新增「加入清單」選擇器：選項為所有現有清單加上「不加入清單」，預設為首頁目前顯示的清單。匯入時，把匯入的股票加入所選清單（已在清單內的略過）。買賣紀錄本身沒有清單欄位，不受影響。
- 匯入完成後回到首頁，首頁清單與小工具立即反映新加入的股票（預覽頁以 push 方式進入，完成後通知首頁重新載入）。
- 匯入紀錄的日期固定為台北時區當日中午 12:00，並在批次內與既有紀錄之間加上遞增的毫秒偏移，確保 Firestore 以時間戳查詢刪除時不會撞號。
- 寫入沿用既有的儲存新買賣紀錄流程，因此本地資料庫與 Firestore 的行為與手動輸入一致，不新增資料欄位，不修改 Core Data 或 Firestore schema。

## Non-Goals

- 不支援券商 API 串接、CSV、Excel 匯入（投資先生不提供；其他券商留待有樣本再評估）。
- 不支援當沖、融資融券、定期定額的成交明細（尚無樣本，辨識到這些類型的筆在預覽頁標示為不支援，不可勾選）。
- 第一版不儲存手續費與交易稅（既有買賣紀錄沒有這兩個欄位，預覽頁僅顯示、不寫入）；若要儲存，另開變更並處理 Core Data 與 Firestore schema。
- 不使用委託書號去重：收合畫面看不到委託書號，且儲存它需要新欄位。
- 不把截圖或辨識文字上傳到任何伺服器，辨識只在裝置端進行。

## Capabilities

### New Capabilities

- `trade-screenshot-import`: 從投資先生成交明細截圖辨識、解析、預覽確認並匯入買賣紀錄，涵蓋解析規則、股名對回股號、去重、預覽頁行為與匯入時選擇加入的清單。

### Modified Capabilities

(none)

## Impact

- Affected specs: 新增 `trade-screenshot-import`
- Affected code:
  - New: MyTaiwanStock/Util/TradeScreenshotParser.swift（解析器，只吃文字與座標）
  - New: MyTaiwanStock/Util/TradeTextRecognizer.swift（封裝 Vision 辨識，輸出文字與座標）
  - New: MyTaiwanStock/Util/StockNameResolver.swift（股名對回股號，可注入清單資料）
  - New: MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift（預覽頁）
  - New: MyTaiwanStock/View Controller/View Model/TradeImportViewModel.swift（匯入流程與去重）
  - New: MyTaiwanStockTests/TradeScreenshotParserTests.swift
  - New: MyTaiwanStockTests/StockNameResolverTests.swift
  - New: MyTaiwanStockTests/TradeImportViewModelTests.swift
  - Modified: MyTaiwanStock/View/FloatingButton.swift（重新設計按鈕外觀）
  - Modified: MyTaiwanStock/View/FloatingButtonManager.swift（展開選單改為毛玻璃膠囊選項，新增「截圖匯入」）
  - Modified: MyTaiwanStock/StockList/ViewController/StockListViewController.swift（實作新的 delegate 方法）
  - Modified: MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift（新增進入匯入流程的導覽方法，以及匯入完成後重新載入清單與小工具資料的方法）
  - Modified: MyTaiwanStock/StockList/StockListCoordinator.swift 內的 StockListCoordinatorProtocol（新增開啟匯入流程的方法）
  - Modified: MyTaiwanStockTests/TestStockListViewModel.swift（MockStockListCoordinator 實作新增的方法）
  - Modified: MyTaiwanStock/StockList/StockListCoordinator.swift（開啟選圖與預覽頁）
  - Modified: MyTaiwanStock.xcodeproj/project.pbxproj（加入新檔案）
- Dependencies: 使用系統框架 Vision 與 PhotosUI（PHPickerViewController），不新增第三方套件。專案最低部署版本改為 iOS 18.0，Vision 的繁體中文辨識與 PHPicker 都可直接使用。
- 相依變更：本變更依賴 refresh-stock-list（股票清單與 StockListRepository），必須等該變更合併後，再從最新的 mvvm 切出本變更的分支。
