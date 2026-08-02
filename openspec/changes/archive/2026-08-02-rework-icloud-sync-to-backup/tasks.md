## 1. 核心抽象層（新增 ICloudBackupService 取代即時 CloudKit 鏡射 / 依賴抽象化以支援擴充與測試）

- [x] 1.1 新增 `Clock` protocol（`func now() -> Date`）與其預設實作 `SystemClock`，讓所有時間相關邏輯改為透過注入的 clock 取得時間；驗證方式：單元測試以 fake `Clock` 回傳固定時間並斷言呼叫方拿到該固定值。
- [x] 1.2 新增 `ICloudAvailabilityChecking` protocol（`func isICloudAvailable() -> Bool`）與其預設實作（包裝 `FileManager.default.ubiquityIdentityToken`）；驗證方式：單元測試以 fake 實作回傳 `false`，斷言依賴方不會嘗試存取 iCloud。
- [x] 1.3 新增 `BackupDestination` protocol（`func write(snapshotAt url: URL) throws`、`func latestSnapshotURL() -> URL?`）與其預設實作（寫入 iCloud Drive ubiquity container）；驗證方式：單元測試以寫入暫存目錄的 fake destination 驗證 `write` 被正確呼叫且檔案存在。
- [x] 1.4 新增 `BackupTriggerReason` enum（`.didEnterBackground`、`.appLaunch`、`.manual`）與 `ICloudBackupService` protocol（`backupIfNeeded(reason:)`、`restoreLatestSnapshot()`、`manualBackupNow()`），並實作 `DefaultICloudBackupService` 整合上述三個依賴；驗證方式：單元測試涵蓋「有變動且超過節流時間才呼叫 write」「距上次備份 59 分鐘/60 分鐘/59分59秒三種邊界情況」「iCloud 不可用時完全不呼叫 write」。

## 2. LocalDBService 崩潰修復與容器簡化（崩潰修復方式：優雅降級取代 fatalError）

- [x] 2.1 將 `URL.storeURL(for:databaseName:)` 回傳型別改為 `URL?`，App Group 容器取得失敗時記錄錯誤並回傳 `nil`；`LocalDBService` 初始化時對 `nil` 結果維持 `fatalError` 並顯示明確的 entitlement 設定錯誤訊息；驗證方式：單元測試傳入不存在的 app group 識別碼，斷言回傳 `nil` 而非崩潰。
- [x] 2.2 落實 Graceful degradation when iCloud is unavailable：`LocalDBService` 移除依 `syncPreference` 切換 `NSPersistentCloudKitContainer`／`NSPersistentContainer` 的邏輯，一律使用 `NSPersistentContainer`；初始化前透過 `ICloudAvailabilityChecking` 檢查 iCloud 可用性，不可用時記錄警告並停用備份功能但不影響本機讀寫；驗證方式：手動於模擬器登出系統 iCloud 帳號後啟動 App，確認不崩潰且清單/交易紀錄可正常新增查詢。
- [x] 2.3 `LocalDBService.saveContext()` 存檔失敗時改為記錄錯誤並發出 `.dataSaveDidFail` `NotificationCenter` 通知，移除 `fatalError`；驗證方式：單元測試以會拋錯的 in-memory context 驗證通知確實被發出且函式正常返回（不崩潰）。
- [x] 2.4 `loadPersistentStores` 新增對 `CKError` 的 `.notAuthenticated`、`.networkUnavailable`、`.serverRecordChanged`、`.zoneNotFound`、`.partialFailure`、`.quotaExceeded` 六種錯誤分類記錄且不中斷初始化，其餘未知錯誤維持 `fatalError`；驗證方式：單元測試以六種對應 `NSError`／`CKError` code 逐一驗證不觸發 `fatalError` 路徑（透過可注入的錯誤處理 closure 驗證分類邏輯，而非直接呼叫真正的 `fatalError`）。

## 3. 定時備份觸發整合（新增 ICloudBackupService 取代即時 CloudKit 鏡射）

- [x] 3.1 實作 Periodic iCloud snapshot backup：在 App 進入背景的生命週期回呼中，使用 `beginBackgroundTask` 取得背景執行時間，呼叫 `ICloudBackupService.backupIfNeeded(reason: .didEnterBackground)`；驗證方式：手動測試情境——修改本機清單後將 App 切至背景，確認 iCloud Drive ubiquity container 內出現新快照檔案且時間戳更新。
- [x] 3.2 在 App 啟動與回到前景的生命週期回呼中，呼叫 `ICloudBackupService.backupIfNeeded(reason: .appLaunch)`；驗證方式：手動測試——距上次備份超過 1 小時且有資料變動時重啟 App，確認觸發一次備份。
- [x] 3.3 在設定頁新增「立即備份」按鈕，呼叫 `ICloudBackupService.manualBackupNow()` 略過節流判斷；驗證方式：手動點擊按鈕，確認無論距上次備份時間多久都會產生新快照。

## 4. 還原流程（還原權威來源判斷 / restore scoped to users without a Firebase login）

- [x] 4.1 實作 Restore scoped to users without a Firebase login：App 啟動時，若本機 Core Data store 為空、使用者未登入 Firebase、且 iCloud 有備份快照，彈出提示詢問是否從 iCloud 備份還原，確認後呼叫 `ICloudBackupService.restoreLatestSnapshot()` 覆蓋本機 store；驗證方式：手動測試——全新安裝 App（未登入 Firebase）且 iCloud 已有先前備份快照時，確認出現還原提示且確認後資料正確回復。
- [x] 4.2 確保使用者已登入 Firebase 時，App 啟動流程不觸發 iCloud 還原提示，維持既有 `getAllListAndStocksFromOnlineDBAndSaveToLocal`／`getAllHistoryFromOnlineDBAndSaveToLocal` 的 Firestore 資料抓取為唯一還原依據；驗證方式：手動測試——已登入帳號的裝置重灌 App 後啟動，確認不出現 iCloud 還原提示，且資料透過 Firestore 正確帶回。

## 5. 登入匯入確認（local data import confirmation on Firebase login / Firestore as authoritative restore source after login）

- [x] 5.1 實作 Local data import confirmation on Firebase login：在 `AccountViewController` 的 Firebase 登入成功回呼中，呼叫 `LocalDBService.shared.fetchAllListFromDB()` 檢查本機是否已有資料，非空時彈出確認對話框詢問是否匯入本機資料到雲端帳號；驗證方式：手動測試——本機已有清單資料時登入新的 Firebase 帳號，確認出現確認對話框。
- [x] 5.2 使用者確認匯入時，逐筆呼叫既有的 `uploadListToOnlineDB`／`uploadNewStockNoToOnlineDB`／`uploadHistoryToOnlineDB` 上傳本機資料；使用者取消時不呼叫任何上傳函式且本機資料維持不變；驗證方式：單元測試以 mock 的 `OnlineDBService` 驗證「確認」路徑呼叫上傳函式、「取消」路徑完全不呼叫。
- [x] 5.3 落實 Firestore as authoritative restore source after login：登入後的所有清單/交易紀錄讀取一律透過既有 Firestore 抓取機制，不讀取或合併 iCloud 備份快照內容；驗證方式：程式碼審查確認登入後資料讀取路徑（`NetworkServiceImpl`）沒有呼叫 `ICloudBackupService.restoreLatestSnapshot()`。

## 6. 設定頁文案與獨立開關（independent optional toggles with combined-off warning）

- [x] 6.1 在 `SettingViewController` 的 iCloud 備份開關旁新增說明文字，明確標示這是「定期本機裝置備份」而非即時同步；驗證方式：手動於模擬器開啟設定頁確認文字顯示正確。
- [x] 6.2 在 `SettingViewController` 的 Firebase 帳號登入區塊新增說明文字，明確標示登入後可跨裝置/跨平台（含 Android）同步；驗證方式：手動於模擬器開啟設定頁確認文字顯示正確。
- [x] 6.3 落實 Independent optional toggles with combined-off warning：當 iCloud 備份關閉且使用者未登入 Firebase 時，在設定頁顯示提醒文字（資料遺失將無法復原），但不阻擋任何操作；驗證方式：手動測試——同時關閉兩者後開啟設定頁，確認提醒文字出現且其他功能仍可正常使用。

## 7. 回歸驗證

- [x] 7.1 執行既有單元測試套件與本次新增的單元測試，確認全數通過；驗證方式：執行 `xcodebuild test` 對應 scheme，確認 build 與測試結果為 success。
- [x] 7.2 手動驗證登入/登出 Firebase 與開關 iCloud 備份的四種組合（都開、都關、各開一個）下 App 均可正常啟動與操作，不出現先前的 `fatalError` 崩潰；驗證方式：於模擬器分別切換四種組合並記錄操作結果。

## 8. 備份/還原檔案安全性修復（review 發現，對應 design.md「備份/還原檔案安全性修復（多面向 review 發現）」）

- [x] 8.1 `BackupDestination.write(snapshotAt:)` 與 `ICloudBackupService.restoreLatestSnapshot()` 改用 `NSFileCoordinator` 包裹對 ubiquity container 快照檔案與本機 store 檔案的讀寫，避免與 iCloud 同步或 Core Data 內部存取產生競態；驗證方式：單元測試以 fake coordinator 驗證 `write`/`restoreLatestSnapshot` 執行期間確實透過 `NSFileCoordinator.coordinate` 呼叫，且未協調時不直接呼叫 `FileManager` API。
- [x] 8.2 備份與還原流程正確處理 Core Data WAL 模式下的 `-wal`/`-shm` 附屬檔案（備份前對 store 執行 checkpoint 使 WAL 內容併回主檔案，或連同附屬檔案一併複製/清除），確保快照包含最新已提交的寫入且還原後不殘留舊 WAL 內容；驗證方式：整合測試——寫入一筆資料後立即觸發備份，讀取快照檔案內容驗證包含該筆資料；另測試還原後舊 `-wal`/`-shm` 檔案已被清除或替換。
- [x] 8.3 `restoreLatestSnapshot()` 覆蓋本機 store 檔案後，呼叫 `persistentStoreCoordinator.remove(_:)` 移除舊 store 並重新 `loadPersistentStores` 載入還原後的檔案，確保執行中的 `NSPersistentContainer` 不再持有指向已覆蓋檔案的舊連線；驗證方式：整合測試——還原後立即對 `LocalDBService` 執行一次寫入與讀取，驗證資料正確寫入還原後的 store 而非造成錯誤或損毀。
- [x] 8.4 `BackupDestination.write` 改為寫入暫存檔名後以 `FileManager.replaceItemAt` 原子性取代舊快照，移除「先刪除、後複製」的兩步驟寫法；驗證方式：單元測試驗證正常寫入流程結果正確，且程式碼中不再有「remove 後再 copy」的分離步驟（可用 mock FileManager 驗證呼叫序列僅出現一次原子替換）。
- [x] 8.5 `restoreLatestSnapshot()` 還原前檢查快照的 Core Data model 版本是否與目前執行版本相容，不相容時記錄錯誤並中止還原（不覆蓋本機 store），回傳可辨識的錯誤而非讓 App 於下次啟動因 migration 錯誤 `fatalError`；驗證方式：單元測試以不相容版本的假快照驗證還原被中止、本機 store 檔案內容未被修改、且呼叫方收到明確錯誤。
- [x] 8.6 `manualBackupNow()`／`backupIfNeeded()`／`restoreLatestSnapshot()` 序列化執行（例如將 `DefaultICloudBackupService` 改為 `actor` 或加入內部 in-flight 旗標），防止使用者連續點擊「立即備份」或手動備份與背景自動備份同時觸發造成同一份檔案並行寫入；`SettingViewController` 的「立即備份」按鈕在備份進行中停用，備份完成後才重新啟用；驗證方式：單元測試以不 await 的方式連續呼叫兩次 `manualBackupNow()`，驗證第二次呼叫被忽略或等待佇列處理、快照檔案內容完整不損毀；手動驗證快速連續點擊「立即備份」按鈕時按鈕確實被停用。
- [x] 8.7 `SceneDelegate.backgroundTaskID` 的讀寫改用同步機制（actor 或等效鎖）保護，避免 `beginBackgroundTask` 到期 callback 與 `Task` 內賦值在不同執行緒同時存取造成 data race；驗證方式：程式碼審查確認所有對 `backgroundTaskID` 的讀寫均經過同步機制，並以 Thread Sanitizer 執行一次背景備份流程確認無 data race 警告。
- [x] 8.8 `restoreLatestSnapshot()` 執行還原前先呼叫 `ICloudAvailabilityChecking.isICloudAvailable()`，與 `backupIfNeeded`／`manualBackupNow` 的檢查方式一致，iCloud 不可用時不嘗試存取快照；驗證方式：單元測試以 fake `ICloudAvailabilityChecking`（回傳 false）驗證 `restoreLatestSnapshot()` 不呼叫 `BackupDestination.latestSnapshotURL()`。
- [x] 8.9 `AccountViewController.offerLocalDataImportIfNeeded` 記錄「本次登入 session 是否已詢問過匯入」的狀態，避免同一帳號重複登入/登出時對已處理過的本機資料重複詢問並重複上傳造成 Firestore 資料重複；驗證方式：單元測試以 mock `OnlineDBService` 驗證同一 session 內第二次呼叫 `offerLocalDataImportIfNeeded` 不再觸發確認對話框或重複上傳。
- [x] 8.10 `SceneDelegate.sceneWillEnterForeground` 改用獨立的 `BackupTriggerReason` case（而非重用 `.appLaunch`）呼叫 `triggerICloudBackupIfEnabled`，讓啟動與回前景成為可區分的觸發來源；驗證方式：單元測試驗證回前景時傳入 `ICloudBackupService.backupIfNeeded(reason:)` 的參數為新的 case 而非 `.appLaunch`。
- [x] 8.11 `SettingViewController` 的「立即備份」`Task` 改用 `[weak self]` 捕獲並在 `await` 之後以 `guard let self else { return }` 檢查，避免使用者在備份進行中離開設定頁後仍嘗試對已釋放/已從畫面移除的 view controller 呈現結果提示；驗證方式：手動測試——點擊「立即備份」後立即切換離開設定頁，確認不會有多餘的 alert 呈現或 console 警告，且 view controller 生命週期正常結束。
- [x] 8.12 （原任務改為「確認並記錄命名決策」，而非重新命名）驗證後發現 Swift 標準函式庫本身已定義 `protocol Clock`（`var now: Instant`，來自 Swift Concurrency，任何檔案不需額外 import 即可見），若將 `BackupClock`／`SystemBackupClock` 改名為 `Clock`／`SystemClock` 會與標準函式庫的 `Clock` 產生命名衝突／遮蔽（`clock.now()` 呼叫會被解析成標準函式庫回傳 `Instant` 的 `now` 屬性而非本專案回傳 `Date` 的 `now()` 方法，導致編譯錯誤）；因此維持 `BackupClock`／`SystemBackupClock` 命名不變，並在 `Clock.swift` 加入註解說明這是刻意選擇，同時撤銷 8.12 原先「1.1 命名不符」的認定——1.1 當初的命名就是正確、刻意迴避衝突的設計；驗證方式：`xcodebuild build` 成功、`ICloudBackupServiceTests` 全數通過（已完成，見 2026-08-02 test run）。
- [x] 8.13 修復 `AccountViewControllerImportTests` 中「使用者取消匯入」的測試——目前該測試未實際觸發 alert 的取消 action、也未操作 view controller，只是重複斷言 mock 狀態，屬於恆真的無效測試；改為透過可測試的方式（例如注入 alert-presenter 或暴露取消 handler）實際觸發取消路徑並驗證 `OnlineDBService` 相關上傳函式完全未被呼叫、本機資料未變動；驗證方式：修改後的測試在 handler 未被觸發時應會失敗（可用「暫時移除取消邏輯」的方式反向確認測試具備偵錯能力），修改後執行 `xcodebuild test` 確認通過。
- [x] 8.14 新增 `SceneDelegate.offerICloudRestoreIfApplicable` 與 `triggerICloudBackupIfEnabled` 背景任務處理的單元測試，涵蓋「本機為空且未登入 Firebase 且有快照時彈出還原提示」「已登入 Firebase 時不彈出還原提示」「背景任務到期前後 `backgroundTaskID` 正確設值與清除」三種情境；驗證方式：新增對應單元測試（可透過抽出可注入依賴的方式讓 `SceneDelegate` 邏輯可測試），執行 `xcodebuild test` 確認全數通過。
