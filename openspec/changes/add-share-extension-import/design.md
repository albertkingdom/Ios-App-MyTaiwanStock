## Context

截圖匯入（trade-screenshot-import）目前的入口只有列表頁浮動按鈕的「截圖匯入」，流程在 MyTaiwanStock/StockList/TradeImportFlow.swift：用 PHPicker 選圖、逐張辨識、合併成交紀錄、推出確認預覽頁，使用者按「匯入」後才寫入。辨識使用 Vision，記憶體用量大，不適合放進 App extension（extension 的記憶體上限小）。

專案已有 App Group：group.a2006mike.myTaiwanStock，主 App 與小工具 extension 的 entitlements 都已宣告，Core Data 的本機資料庫也放在這個共用容器。專案已有兩個 extension（小工具、Live Activity），它們的 Debug 與 Release 設定是新 target 的對照：手動簽署並指定 match 的 profile、SKIP_INSTALL、entitlements、Info.plist 與顯示名稱等。簽署由 fastlane match（appstore 類型）管理，Fastfile 的 sync_signing 與 beta 兩個 lane 各自寫死 App ID 清單；CI 使用唯讀的 match deploy key，所以 profile 必須先由本機寫進 match 倉庫。

現況的限制，設計必須處理：

- TradeImportFlow 的 onFinished 只在三處被呼叫（選取器取消、提示框按「好」、預覽頁匯入完成）；預覽頁沒有取消鈕，使用者按導覽列返回時沒有任何回報，StockListCoordinator 的 importFlow 因此永遠不會被清掉。
- SceneDelegate 的 AppCoordinator 與 tabBarController 是區域變數；列表頁的 listNames 與 currentListName 只存在 StockListViewModel，由列表頁出現時載入。
- 主 App 啟動時會非同步跳出 iCloud 還原提示，列表頁首次出現會跳出教學，首次啟動還有推播授權對話框，這些都會在 window 上 present 畫面。
- 主 App 是單一 scene、僅 iPhone，使用者從其他 App 分享後，本 App 一定在背景或已終止，回來時 sceneDidBecomeActive 會觸發。
- 最低部署版本是 iOS 18.0。

## Goals / Non-Goals

**Goals:**

- 使用者在任何 App 的分享選單選「MyTaiwanStock」，圖片被安全地存進待匯入資料夾。
- 主 App 回到前景時詢問使用者，同意後沿用現有辨識與確認預覽，使用者按「匯入」前不寫入任何紀錄。
- 待匯入圖片保存的時間最短、受到保護，辨識完成就刪除。

**Non-Goals:**

- 不在 extension 內辨識文字，也不在 extension 內寫入任何資料庫。
- 不由 extension 自動開啟主 App，也不在本次加入本機通知。
- 不處理圖片以外的分享內容，張數上限 10 張維持不變（這是使用體驗的限制，不是技術限制）。
- 不上傳圖片，也不透過 iCloud 或 Firebase 同步或備份待匯入資料夾。
- 預覽期間不保留圖片：預覽期間 App 被系統回收時，使用者需要重新分享。

## Decisions

### 簽署與 App ID

新增 bundle id com.a2006mike.MyTaiwanStock.ShareExtension，啟用既有的 App Group。先在 Apple Developer 後台建立 App ID 並勾選 App Groups，再在本機（有寫入權限）跑 fastlane 的 sync_signing，appstore 與 development 兩種類型都要產生 profile；之後用唯讀模式再跑一次確認 CI 能取得，並用 security cms 檢查 profile 含 App Group。Fastfile 把四個 App ID 抽成單一常數，sync_signing 與 beta 共用。Matchfile 與 testflight.yml 不需要改。

新 target 的 Debug 與 Release 設定逐項照小工具 extension 複製：手動簽署（CODE_SIGN_STYLE 為 Manual）、開發團隊、簽署身分、PROVISIONING_PROFILE_SPECIFIER（Release 是 match AppStore 加 bundle id，Debug 是 match Development 加 bundle id）、SKIP_INSTALL、CODE_SIGN_ENTITLEMENTS、INFOPLIST_FILE、顯示名稱、LD_RUNPATH_SEARCH_PATHS、部署版本 18.0，行銷版本與主 App 一致（1.23）。Xcode 精靈預設的自動簽署不可保留。Info.plist 不寫版本字面值。

新 target 建好後、功能開發前，必須在本機用 match 唯讀加 build_app（不上傳）完整乾跑一次封存與匯出，確認 ShareExtension.appex 被嵌入並簽署成功；ci.yml 加一步 ShareExtension 的 target 建置。原因：簽署是最可能卡住發版的部分，晚發現成本最高，實際的 TestFlight 上傳放在最後驗證。

### Extension 的介面、啟用規則與顯示名稱

Extension 用最小的 UIViewController，不使用系統的撰寫畫面。Info.plist 明確設定：NSExtensionPointIdentifier 為 com.apple.share-services，NSExtensionPrincipalClass 為 $(PRODUCT_MODULE_NAME).ShareViewController，NSExtensionActivationRule 用字典並只含 NSExtensionActivationSupportsImageWithMaxCount（值 10），不留精靈預設的 TRUEPREDICATE。顯示名稱用 INFOPLIST_KEY_CFBundleDisplayName 設為 MyTaiwanStock，和桌面上 App 圖示下方的名稱一致；確認文字為「已加入待匯入，請開啟 MyTaiwanStock 確認」。裝置家族與主 App 相同，只支援 iPhone。

### Extension 讀取與複製圖片的方式

Extension 把所有分享項目的附件攤平，只處理圖片附件，原樣複製，不做任何辨識。每張圖片用 loadFileRepresentation 取得暫存檔，並且必須在回呼內完成複製（回呼返回後系統會刪除暫存檔）；副檔名取自交付的檔案；檔名依附件的索引命名，不依完成順序，因為各附件並行載入。不使用 loadDataRepresentation，避免把整張原圖讀進記憶體。iCloud 照片尚未下載時載入會延遲，這段時間顯示載入狀態，全部完成才結束 extension；任何一張失敗，就刪除整批並以錯誤結束。

### 待匯入資料夾的結構、保存期限與隱私保護

待匯入根資料夾是 App Group 容器下的 PendingImports。每次分享先在根資料夾內建立以固定前綴開頭的暫存資料夾，寫完所有圖片後改名成正式批次，批次資料夾名稱是「毫秒時間戳、連字號、UUID」，時間戳編在名稱裡，排序與過期都不依賴檔案屬性，測試也不必改檔案屬性。圖片檔依序命名並保留原副檔名。

保存期限最長 24 小時：每次檢查待匯入資料夾時，名稱時間戳超過 24 小時的批次，以及超過 1 小時仍殘留的暫存資料夾（extension 被終止留下的孤兒），一律刪除。

保護：根資料夾設為排除備份（不進 iCloud 裝置備份與電腦備份）；資料夾與檔案寫入後設為最高等級的檔案保護（鎖屏時無法讀取）；不產生縮圖；紀錄檔不寫入圖片內容或辨識內容。因為鎖屏時讀不到，讀取失敗視為暫時無法讀取，不當作錯誤也不刪除批次。待匯入根資料夾只由 PendingImportStore 存取。

PendingImportStore 放在 MyTaiwanStock/Util/PendingImportStore.swift，同時加入主 App 與 ShareExtension 兩個 target，只依賴 Foundation：不使用全域 logger，不使用 LocalDBService 的 App Group 常數（該檔引用 CoreData、CloudKit、UIKit），容器位置由呼叫端注入，測試用暫存目錄。寫入 API 接收檔案 URL 而不是圖片資料，並由 store 負責「先寫暫存、再改名」。

### 圖片辨識完成後立即刪除

這是使用者在隱私與不遺失之間做的決定：圖片只在「分享後到辨識完成」這段時間存在。一個批次的所有圖片都辨識完，且結果已確定（有成交紀錄、沒有成交紀錄、或辨識失敗並顯示提示）時，在顯示預覽或提示之前刪除該批次；預覽使用記憶體中的辨識結果。因系統中斷而被取消的辨識（例如 App 進入背景）不算結果，批次保留，下次再處理。代價：預覽期間 App 被系統回收，或使用者在預覽頁返回，這批圖不會再出現，需要重新分享；原始截圖通常還在相簿。

### 主 App 回到前景時詢問並接手

接手邏輯放進一個可測試的小物件 PendingImportCoordinator（MyTaiwanStock/Util/PendingImportCoordinator.swift），SceneDelegate 在 sceneDidBecomeActive 只呼叫它；它的檢查另外在匯入流程結束時、列表頁出現時觸發。檢查的條件依序是：

1. 有待匯入批次（先清除過期批次）。
2. 目前沒有匯入流程進行中。
3. 畫面上沒有其他 modal：從 window 的 rootViewController 沿 presentedViewController 往下找，非 nil 就視為有，iCloud 還原提示與教學也算在內，條件不成立就等下一次觸發，不排隊。

條件都成立時跳出提示「有 N 張待匯入的截圖，要現在匯入嗎？」，兩個選項：「現在匯入」與「稍後」。選「現在匯入」才切到列表 tab、回到列表根頁（不做動畫，放棄子頁上未存的內容，這是使用者按下的結果）、再以最舊的批次啟動流程；選「稍後」保留批次，下次回到前景再問。同一次回到前景最多問一次。路徑是 window 的 rootViewController、CustomTabBarViewController、第一個 tab 的 StockListViewController，由它的新方法帶入 listNames 與 currentListName，內部沿用既有的匯入入口。冷啟動時延後一個 run loop 再檢查，讓 iCloud 還原提示等先出現。

### 匯入流程的進行中與結束狀態

匯入流程用明確的狀態（進行中、已結束）表示，不再用 importFlow 是否為 nil 判斷。預覽頁在被移出導覽堆疊（didMove 到 nil parent）時回報已關閉；流程的結束動作必須冪等，因為匯入路徑同時有回到根頁與 onFinished；結束後由 coordinator 主動重新檢查待匯入批次，讓下一批可以詢問。載入期間重複的 active 通知不會啟動第二個流程。

### 圖片來源抽象化

TradeImportFlow 接受一個「圖片來源」：提供圖片張數、逐張載入圖片資料（辨識完一張就釋放，不把全部圖片一次載入記憶體）、以及收尾動作。系統相簿選取器與待匯入批次各是一個來源。兩者進入方式不同（選取器要先呈現並可能被取消，批次直接開始），流程以「開始」的方式分流。刪除批次是待匯入來源的收尾動作，流程不認識 store。為了可測試，流程的確認預覽 view model 建立方式與載入畫面的最短停留時間改成可注入，預設值維持現狀。若改動 StockListCoordinator 的 protocol，TestStockListViewModel 裡的 MockStockListCoordinator 同步更新。

## Implementation Contract

**Behavior:**

- 分享圖片後，Extension 在待匯入資料夾建立一個批次並顯示確認；使用者尚未開啟主 App 時，批次留在裝置上，最長 24 小時。
- 主 App 回到前景、有待匯入批次且畫面上沒有其他流程或 modal 時，跳出「要現在匯入嗎？」；選「現在匯入」後列表頁出現載入畫面，辨識完成後進入既有的確認預覽頁；沒有成交紀錄時顯示既有的「找不到可匯入的成交紀錄」提示。
- 沒有待匯入批次時，主 App 的行為與現在完全相同。
- 批次的圖片在辨識完成、顯示預覽或提示之前刪除。

**Interface / data shape:**

- 待匯入資料夾：App Group 容器下的 PendingImports/，內含暫存資料夾（固定前綴）與正式批次資料夾（毫秒時間戳加 UUID），批次內是依序命名的圖片檔。
- PendingImportStore：寫入一批圖片檔、列出批次（依名稱時間戳由舊到新）、取得批次的圖片檔位置、刪除批次、清除過期批次與殘留暫存資料夾；只依賴 Foundation，容器位置注入。
- PendingImportCoordinator：輸入是 store、目前是否有流程、目前是否有 modal；輸出是「要不要詢問、批次有幾張」以及使用者選擇後的動作；SceneDelegate 與列表頁只呼叫它。
- 圖片來源：圖片張數、逐張載入圖片資料、收尾動作。

**Failure modes:**

- 單張圖片無法讀取或辨識失敗：沿用既有的「無法讀取圖片」提示，批次在提示顯示前刪除。
- 辨識被系統中斷：保留批次。
- Extension 複製中途失敗或任一附件載入失敗：刪除該批次並顯示錯誤，不留下不完整的批次。
- App Group 容器不存在：Extension 顯示錯誤；主 App 視為沒有批次，不崩潰。
- 鎖屏時讀不到檔案：視為暫時無法讀取，不刪除。

**Acceptance criteria:**

- PendingImportStoreTests 涵蓋：寫入後可列出且內容一致、依時間戳排序、刪除後消失、超過 24 小時的批次與超過 1 小時的暫存資料夾被清除、空資料夾與容器不存在時不崩潰、寫入中途失敗不留下半個批次、根資料夾排除備份、檔案保護等級正確。
- PendingImportCoordinatorTests 涵蓋：流程進行中不詢問、有 modal 不詢問、選「稍後」保留批次、選「現在匯入」切到列表根頁並啟動、同一次前景最多問一次、結束後會再檢查下一批。
- TradeImportFlowTests 涵蓋：用假的來源與假的辨識器，預覽頁被推出且內容與現有相同；來源丟錯誤時顯示提示且不寫入紀錄；辨識完成時批次已刪除；辨識被取消時批次仍在；預覽頁被關閉後流程狀態回到已結束。
- 手動驗證：在模擬器的照片 App 分享圖片到本 App，再開啟本 App，看到詢問與確認預覽，按匯入前資料庫沒有新紀錄；選「稍後」後批次仍在；在股票詳情頁時選「現在匯入」會回到列表根頁。
- fastlane 的簽署 lane 能為新的 bundle id 產生 appstore 與 development profile，本機封存乾跑成功，TestFlight 上傳成功。

**Scope boundaries:**

- 範圍內：Share Extension target、待匯入資料夾與存取物件、接手詢問與流程狀態、流程圖片來源抽象化、fastlane 與 CI 的簽署設定、對應測試與規格、版號 1.23。
- 範圍外：extension 內辨識、本機通知、自動開啟主 App、圖片以外的分享內容、同步或備份待匯入資料夾、Android、PrivacyInfo 隱私清單（正式送審時再補）。

## Risks / Trade-offs

- [簽署或 App ID 設定卡住] → 第一個任務先建立 App ID 並產生兩種 profile，新 target 建好後做封存乾跑，通過才開始寫功能。
- [CI 的 match 金鑰唯讀，profile 沒先寫進倉庫會在發版時失敗] → 在本機寫入後用唯讀模式再確認一次。
- [Extension 的啟用規則寫錯，分享選單看不到本 App] → 規則只用圖片這一項、最多 10 張，在模擬器與真機都驗證分享選單有出現，且文字與網址不出現。
- [兩個 target 共用 PendingImportStore，遺漏 target membership 或誤用 UIKit、CoreData 造成編譯失敗] → 任務中明列兩個 target 都要加入，ci.yml 加 ShareExtension 的建置，共用檔只用 Foundation。
- [預覽期間 App 被回收或使用者在預覽頁返回，圖片已刪除] → 這是為了隱私做的取捨；原始截圖通常仍在相簿，可再分享一次，並明確寫進使用者說明。
- [使用者分享後沒有開啟主 App，圖片留在裝置上] → 24 小時期限與加密保護、排除備份。
- [Extension 被系統終止於複製途中] → 先寫暫存資料夾、完成後再改名；孤兒暫存資料夾超過 1 小時就清除；主 App 只讀取完整批次。
- [接手詢問與 iCloud 還原提示、教學互搶畫面] → 有任何 modal 就不詢問，等下一次觸發（結束、列表頁出現、再次回到前景）；冷啟動延後一個 run loop。
- [圖片載入需要時間（iCloud 照片尚未下載）] → Extension 顯示載入狀態，全部完成才結束。

## Open Questions

- 分享完成後是否要加一則本機通知提醒使用者開啟 App：本次不做，等使用實際體驗後再決定。
