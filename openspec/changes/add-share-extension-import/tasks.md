## 1. 簽署與 App ID（先確認能簽署）

- [x] 1.1 簽署與 App ID：在 Apple Developer 後台建立 App ID com.a2006mike.MyTaiwanStock.ShareExtension 並勾選 App Groups（既有的 group.a2006mike.myTaiwanStock）；把 fastlane/Fastfile 的四個 App ID 抽成單一常數，sync_signing 與 beta 兩個 lane 共用。完成後 match 能為新 ID 產生 appstore 與 development 兩種 profile，CI 的唯讀金鑰也取得得到。驗證：在本機（有寫入權限）執行 fastlane 的 sync_signing，type 分別為 appstore 與 development，都成功結束；再以唯讀模式執行 sync_signing 成功；用 security cms 解開新 profile，確認含 App Group group.a2006mike.myTaiwanStock。

## 2. Share Extension target

- [x] 2.1 新增 ShareExtension target 與版號：Debug 與 Release 都照小工具 extension 設定（手動簽署、開發團隊、簽署身分、PROVISIONING_PROFILE_SPECIFIER 為 match AppStore 或 match Development 加 bundle id、SKIP_INSTALL、CODE_SIGN_ENTITLEMENTS 指向 ShareExtension/ShareExtension.entitlements、INFOPLIST_FILE 指向 ShareExtension/Info.plist、LD_RUNPATH_SEARCH_PATHS、部署版本 18.0），entitlements 宣告既有 App Group，target 嵌入主 App，Info.plist 不寫版本字面值。MARKETING_VERSION 在主 App、小工具、Live Activity、ShareExtension 四個 target 都改為 1.23，這個版號改動獨立成一個 commit。驗證：模擬器 build MyTaiwanStock scheme 成功，產物的 PlugIns 內有 ShareExtension.appex；xcodebuild 的 showBuildSettings 顯示四個 target 的 MARKETING_VERSION 都是 1.23，且 ShareExtension 的簽署設定與小工具逐項一致。
- [x] 2.2 Extension 的介面、啟用規則與顯示名稱：Info.plist 設定 NSExtensionPointIdentifier 為 com.apple.share-services、NSExtensionPrincipalClass 為 $(PRODUCT_MODULE_NAME).ShareViewController、NSExtensionActivationRule 為只含 NSExtensionActivationSupportsImageWithMaxCount（值 10）的字典；顯示名稱設為 MyTaiwanStock；裝置家族只支援 iPhone。驗證：在模擬器的照片 App 選一張圖片開啟分享選單可看到「MyTaiwanStock」，在 Safari 分享網頁時看不到，一次選 11 張圖片時也看不到。
- [x] 2.3 簽署乾跑與 CI 建置檢查：在 ci.yml 加入 ShareExtension 的 target 建置步驟（和小工具、Live Activity 一樣），並在本機以 match 唯讀加 fastlane 的 build_app（不上傳）完整乾跑封存與匯出。驗證：乾跑成功且匯出的 IPA 內含簽署過的 ShareExtension.appex；ci.yml 的 ShareExtension 建置步驟在 CI 通過；這一關通過之前不開始第 3 組。

## 3. 待匯入資料夾與存取物件

- [x] 3.1 待匯入資料夾的結構、保存期限與隱私保護：新增 MyTaiwanStock/Util/PendingImportStore.swift 並同時加入主 App 與 ShareExtension 兩個 target，只引用 Foundation，容器位置由呼叫端注入。提供：寫入一批圖片檔（先寫固定前綴的暫存資料夾，完成後改名為「毫秒時間戳、連字號、UUID」的批次資料夾，圖片依序命名並保留原副檔名）、列出批次（依名稱時間戳由舊到新）、取得批次的圖片檔位置、刪除批次、清除超過 24 小時的批次與超過 1 小時的殘留暫存資料夾；根資料夾排除備份，檔案與資料夾設為最高等級的檔案保護，不產生縮圖，不寫入圖片內容的紀錄，鎖屏讀不到時視為暫時無法讀取。驗證：兩個 target 都能編譯；3.2 的測試通過。
- [x] 3.2 新增 MyTaiwanStockTests/PendingImportStoreTests.swift 並加入測試 target（Pending images stay on the device and are protected）：寫入後可列出且內容一致、多批次依時間戳排序、刪除後消失、超過 24 小時的批次與超過 1 小時的暫存資料夾被清除、空資料夾與容器不存在時不崩潰、寫入中途失敗不留下半個批次、根資料夾排除備份、檔案保護等級正確。另外全專案搜尋 PendingImports 只出現在 PendingImportStore、其測試與 ShareExtension，且 iCloud 備份與 Firebase 同步的程式碼（MyTaiwanStock/Util/OnlineDBService.swift 與 iCloud 備份服務）都不讀取它。驗證：這些測試在 iPhone 模擬器全部通過，搜尋結果符合上述範圍。

## 4. Extension 實作

- [x] 4.1 Extension 讀取與複製圖片的方式：新增 ShareExtension/ShareViewController.swift，把所有分享項目的附件攤平、只處理圖片，用 loadFileRepresentation 並在回呼內經 PendingImportStore 寫成一批，檔名依附件索引、副檔名取自交付的檔案；載入期間顯示載入狀態，全部完成才顯示「已加入待匯入，請開啟 MyTaiwanStock 確認」並結束（Share sheet accepts images and stores them for later import）；任何一張失敗就刪除該批次並顯示錯誤，不做辨識、不寫任何紀錄。驗證：模擬器分享 2 張圖，App Group 容器出現含 2 個依序命名的檔案的批次資料夾且資料庫沒有新紀錄；用唯讀的資料夾模擬複製失敗時看到錯誤且沒有批次；分享一張尚未下載的 iCloud 照片時有載入狀態且最後成功。

## 5. 匯入流程與主 App 接手

- [x] 5.1 匯入流程的進行中與結束狀態：在 MyTaiwanStock/StockList/TradeImportFlow.swift 與 MyTaiwanStock/StockList/StockListCoordinator.swift 以明確狀態表示進行中與已結束；MyTaiwanStock/View Controller/TradeImportPreviewViewController.swift 在被移出導覽堆疊時回報已關閉；結束動作冪等；結束後 coordinator 重新檢查待匯入批次；載入期間重複的 active 通知不會啟動第二個流程。驗證：新增 MyTaiwanStockTests/TradeImportFlowTests.swift，涵蓋預覽頁返回後流程回到已結束、匯入完成與返回各只結束一次、結束後 coordinator 被通知；既有的 TradeImportViewModelTests 通過。
- [x] 5.2 圖片來源抽象化（Recognize trades from screenshots on device）：TradeImportFlow 接受提供張數、逐張載入圖片資料與收尾動作的來源，相簿選取器與待匯入批次各一個實作，辨識一張就釋放一張，兩種來源以「開始」方式分流；確認預覽 view model 的建立方式與載入畫面的最短停留時間可注入，預設行為不變；若動到 coordinator 的 protocol，同步更新 MyTaiwanStockTests/TestStockListViewModel.swift 的 MockStockListCoordinator。驗證：TradeImportFlowTests 用假的來源與假的辨識器，預覽頁被推出且內容與現有相同，來源丟錯誤時顯示提示且不寫入紀錄；既有的 TradeScreenshotParserTests、TradeTextRecognizerTests、TestStockListViewModel 全部通過。
- [x] 5.3 圖片辨識完成後立即刪除（Pending images are deleted after recognition or expiry）：待匯入來源的收尾動作在辨識產生結果（有成交紀錄、沒有成交紀錄、或錯誤並顯示提示）後、顯示預覽或提示之前刪除批次；辨識被系統中斷時保留批次，讀不到圖片是因為裝置已鎖定（資料暫時無法讀取）時也視為被中斷而不是錯誤；每次檢查時清除過期批次。驗證：TradeImportFlowTests 用假來源與假的待匯入存取物件：預覽顯示前批次已刪除、來源丟錯誤時批次也被刪除、辨識被取消時批次仍在；手動把批次資料夾名稱的時間戳改成 25 小時前，下次回到前景該批次被刪除且沒有詢問。
- [x] 5.4 主 App 回到前景時詢問並接手（Pending images are offered for import when the app becomes active）：新增 MyTaiwanStock/Util/PendingImportCoordinator.swift，依「有批次、沒有流程、沒有 modal（沿 presentedViewController 往下找）」判斷是否跳出「有 N 張待匯入的截圖，要現在匯入嗎？」，「現在匯入」才切到列表 tab、回到列表根頁（不做動畫）並以最舊的批次啟動流程，「稍後」保留批次，同一次回到前景最多問一次，冷啟動延後一個 run loop；MyTaiwanStock/SceneDelegate.swift 在 sceneDidBecomeActive 呼叫它，列表頁出現與流程結束時也觸發檢查，列表頁提供帶入 listNames 與 currentListName 的新方法（含 MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift 與 MyTaiwanStock/StockList/ViewController/StockListViewController.swift 的修改）。驗證：新增 MyTaiwanStockTests/PendingImportCoordinatorTests.swift，涵蓋流程進行中不詢問、有 modal 不詢問、選「稍後」保留批次、選「現在匯入」切到列表根頁並啟動、同一次前景最多問一次、結束後會問下一批；手動：在股票詳情頁分享後回來選「現在匯入」會回到列表根頁並出現預覽。

## 6. 驗證與發版前檢查

- [ ] 6.1 手動驗證清單：在 iPhone 17 Pro 與 iPhone Duo 模擬器各跑一次「照片 App 分享圖片 → 開啟本 App → 詢問 → 現在匯入 → 載入畫面 → 確認預覽 → 按匯入」，匯入前資料庫沒有新紀錄、辨識完成後待匯入資料夾為空、匯入後紀錄寫入；再跑「選稍後」「預覽頁返回」「辨識途中進入背景」三個情境，確認批次的保留與刪除符合規格；另外確認在網頁分享與一次選 11 張圖片時分享選單不會出現本 App（2.2 在模擬器只驗證了選一張圖片時會出現）。驗證：兩個模擬器的結果記錄在 PR 描述。
- [ ] 6.2 發版前檢查：TestFlight 建置安裝到真機後，分享選單出現「MyTaiwanStock」，分享一張券商截圖後開啟 App 能完成匯入，鎖屏後再解鎖批次仍可讀。驗證：在真機實際操作並把結果寫進 PR 描述；若 fastlane 或 testflight workflow 因新 target 失敗，修正後再上傳。
