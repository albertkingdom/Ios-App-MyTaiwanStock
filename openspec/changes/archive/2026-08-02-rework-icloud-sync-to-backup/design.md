## Context

App 目前透過 `LocalDBService`（`NSPersistentCloudKitContainer`）對 iCloud 做即時鏡射，同時 `OnlineDBService`／`NetworkServiceImpl` 對 Firebase Firestore 做跨平台（含 Android）同步，兩者無條件同時寫入同一份 Core Data store。`UserPreferences.syncPreference` 目前只切換 CloudKit 容器類型，完全不影響 Firestore 呼叫。設定頁（`SettingViewController`）的開關文字讓使用者誤以為關掉「iCloud 同步」就等於關掉所有雲端同步。

### 改版後的資料流向

使用者建立或修改資料時（例如新增交易紀錄），資料流向如下：

```
使用者操作（新增/修改清單、股票、交易紀錄）
        │
        ▼
NetworkServiceImpl（協調層，例如 saveNewRecord()）
        │
        ├─────────────────────────────┐
        ▼                             ▼
LocalDBService                 （若已登入 Firebase）
  .saveContext()                OnlineDBService
  → 寫入 Core Data                .uploadXxx()
    (唯一本機事實來源)              → 寫入 Firestore
        │
        │  （非同步、非即時，
        │   只在特定時機點觸發）
        ▼
ICloudBackupService.backupIfNeeded(reason:)
  → 複製 Core Data sqlite 快照到 iCloud Drive
```

- **步驟 1（必經、同步）**：無論登入狀態或 iCloud 備份開關為何，使用者動作一律先寫入 Core Data（`LocalDBService.saveContext()`），這是唯一的本機事實來源。
- **步驟 2（條件式、非同步）**：僅在使用者已登入 Firebase 時，`NetworkServiceImpl` 才會呼叫 `OnlineDBService.uploadXxx()` 把該筆異動推上 Firestore；未登入則此步驟完全不執行。
- **步驟 3（延遲、批次、獨立觸發）**：iCloud 備份**不會**在寫入當下被觸發，只在 App 進背景（有變動且距上次備份 ≥1 小時）、App 啟動/回前景、或使用者手動按「立即備份」三個時機點，將當下整個 Core Data 檔案複製一份快照到 iCloud Drive——這是跟改版前最大的差異：改版前 `saveContext()` 會同時觸發即時 CloudKit 推送，跟 Firestore push 兩條雲端路徑互相糾纏；改版後只剩「Firestore（即時、視登入狀態而定）」與「iCloud（定時、視背景/前景時機而定）」兩條互不搶主導權的路徑。

## Goals / Non-Goals

**Goals:**
- 將 iCloud 從即時同步降級為定時本機備份，消除即時 CloudKit 鏡射帶來的崩潰面與雙寫糾纏。
- 修復既有的三個 `fatalError` 崩潰風險與不完整的 CKError 處理。
- 明確定義還原（restore）時的資料權威來源，避免本機資料與 Firestore 資料被靜默合併。
- 備份/還原核心邏輯需可擴充（未來可加其他觸發時機或備份目的地）、可單元測試（不依賴真實系統時間、真實 iCloud 環境）。

**Non-Goals:**
- 不實作雙資料源自動合併演算法。
- 不新增 `BGAppRefreshTask` 系統排程（列為未來擴充項）。
- 不變更 Firestore 的 collection／欄位結構。
- 不處理切換不同 Firebase 帳號時的資料合併情境。

## Decisions

### 新增 ICloudBackupService 取代即時 CloudKit 鏡射

新增 `ICloudBackupService`（protocol + 預設實作 `DefaultICloudBackupService`），取代 `LocalDBService` 中 `NSPersistentCloudKitContainer` 的即時鏡射角色。`LocalDBService` 一律使用一般 `NSPersistentContainer`（不再依 `syncPreference` 切換容器類型），iCloud 備份改為「定期把 Core Data sqlite store 複製一份快照到 iCloud Drive ubiquity container（`group.a2006mike.myTaiwanStock` 對應的 ubiquity container 路徑）」的獨立動作，與 Core Data 的即時寫入路徑完全解耦。

- 替代方案：繼續用 `NSPersistentCloudKitContainer` 但降低同步頻率——不可行，CloudKit container 沒有「降頻」選項，即時鏡射是其唯一運作模式。
- 替代方案：用 CloudKit 手動排程上傳單一 record——複雜度高於直接複製 sqlite 快照，且與「單機備份、非跨裝置即時同步」的定位不符，故不採用。

### 依賴抽象化以支援擴充與測試

`ICloudBackupService` 的介面設計需滿足「可擴充、可測試」需求：

- **時間依賴抽象化**：備份節流判斷（距上次備份 ≥1 小時）透過注入的 `Clock`（protocol，`func now() -> Date`）取得目前時間，不直接呼叫 `Date()`。測試時可注入固定時間的 fake clock，驗證節流邏輯的邊界條件（剛好 1 小時前、59 分鐘前、59 分 59 秒前等）。
- **iCloud 可用性檢查抽象化**：`FileManager.default.ubiquityIdentityToken` 的檢查透過注入的 `iCloudAvailabilityChecking` protocol（`func isICloudAvailable() -> Bool`）取得，測試時可注入固定回傳值的 fake，不需要真實登入/登出 iCloud 帳號即可測試「未登入 iCloud 時的行為」。
- **觸發來源抽象化**：三個觸發點（進背景、啟動/回前景、手動按鈕）都呼叫同一個 `ICloudBackupService.backupIfNeeded(reason:)` 入口方法，`reason` 為 enum（`.didEnterBackground` / `.appLaunch` / `.manual`），未來新增觸發時機（例如 `BGAppRefreshTask`）只需新增呼叫端與對應的 `reason` case，不需修改節流/備份核心邏輯。
- **備份儲存位置抽象化**：sqlite 快照的寫入目的地透過 `BackupDestination` protocol（`func write(snapshotAt url: URL) throws`）抽象，預設實作寫入 iCloud Drive ubiquity container；測試時可注入寫到暫存目錄的 fake destination，驗證「有變動才備份」「節流時間到才備份」的邏輯，不需要實際的 iCloud 環境。

### 崩潰修復方式：優雅降級取代 fatalError

- `LocalDBService` 初始化時檢查 iCloud 可用性（透過上述 `iCloudAvailabilityChecking`），不可用時記錄警告並停用備份功能（不影響本機 Core Data 正常運作），不再假設一定要有 iCloud。
- `URL+Extension.swift` 的 `storeURL(for:databaseName:)` 改為回傳 `URL?`，App Group 容器取得失敗時回傳 `nil` 並記錄錯誤；呼叫端（`LocalDBService` 初始化）在取得 `nil` 時仍以 `fatalError` 處理——因為 App Group 容器是本機資料庫存放位置的必要前提，屬於設定錯誤（entitlement 缺失)而非執行期可恢復的狀態，維持快速失敗，但錯誤訊息需明確指出是 entitlement 設定問題。
- `LocalDBService.saveContext()` 存檔失敗時記錄錯誤並透過 `NotificationCenter` 發出 `.dataSaveDidFail` 通知，不再 `fatalError`；呼叫端可選擇性監聽此通知向使用者顯示提示，但本次不強制要求 UI 端一定要處理。
- `loadPersistentStores` 針對 `CKError` 的 `.notAuthenticated`、`.networkUnavailable`、`.serverRecordChanged`、`.zoneNotFound`、`.partialFailure`、`.quotaExceeded` 六種常見錯誤分類記錄，非上述已知錯誤才維持 `fatalError`（代表未預期的嚴重錯誤，需要開發者介入）。

### 備份/還原檔案安全性修復（多面向 review 發現）

實作完成後的多角度 review（iCloud/CloudKit 正確性、資料安全性、Swift concurrency、一般程式碼審查）發現 `ICloudBackupService`／`BackupDestination` 的檔案層級操作有實質資料損毀風險，須在 apply 階段修復：

- **檔案協調（NSFileCoordinator）**：`BackupDestination.write(snapshotAt:)` 寫入 ubiquity container、以及 `ICloudBackupService.restoreLatestSnapshot()` 覆蓋本機 store 檔案時，一律改用 `NSFileCoordinator` 包裹讀寫操作（`.forReplacing` / `.forMerging` 視情境），避免與 iCloud 同步 daemon 或 Core Data 內部檔案存取產生競態。
- **WAL/SHM 附屬檔案**：備份與還原不能只複製主要 `.sqlite` 檔案，須一併處理 `-wal`、`-shm` 附屬檔案（或在複製前先對 persistent store 執行 checkpoint，確保 WAL 內容已合併回主檔案），避免最近寫入的資料遺失或還原後殘留的舊 WAL 檔案造成損毀。
- **還原後重新載入 store**：`restoreLatestSnapshot()` 覆蓋檔案後，必須呼叫 `NSPersistentStoreCoordinator.remove(_:)` 移除舊 store 並重新 `loadPersistentStores`（或明確要求呼叫端在還原完成後重啟 App 流程），不可讓已開啟的 `NSPersistentContainer` 繼續持有指向舊檔案的連線。
- **原子寫入**：`BackupDestination.write` 改為寫入暫存檔名後以 `FileManager.replaceItemAt` 原子性取代舊快照，避免「先刪除、後複製」兩步驟中間被中斷造成半寫入的損毀快照。
- **Schema 版本檢查**：`restoreLatestSnapshot()` 還原前檢查快照的 Core Data model 版本是否與目前執行版本相容；不相容時記錄錯誤並中止還原（不覆蓋本機 store），並回傳可辨識的錯誤而非讓 App 在下次啟動時因 migration 錯誤 `fatalError`。
- **並行防護**：`manualBackupNow()`／`backupIfNeeded()`／`restoreLatestSnapshot()` 需序列化執行（例如將 `DefaultICloudBackupService` 改為 `actor`，或以內部 in-flight 旗標防止重入），避免使用者連續點擊「立即備份」或手動備份與背景自動備份同時觸發造成同一份檔案的並行寫入。設定頁「立即備份」按鈕在備份進行中需停用，避免重複觸發。
- **`SceneDelegate.backgroundTaskID` 同步**：改用 actor 或等效同步機制保護 `backgroundTaskID` 的讀寫，避免背景任務到期 callback 與 `Task` 內的賦值在不同執行緒同時存取造成 data race。
- **`restoreLatestSnapshot()` 補上可用性檢查**：與 `backupIfNeeded`／`manualBackupNow` 一致，還原前先檢查 `ICloudAvailabilityChecking.isICloudAvailable()`。
- **登入匯入防重複上傳**：`AccountViewController.offerLocalDataImportIfNeeded` 需記錄「本次登入 session 是否已詢問過匯入」的狀態（例如以 `UserDefaults` 或記憶體旗標標記已處理），避免同一帳號重複登入/登出時對已上傳過的本機資料重複詢問並重複上傳造成 Firestore 資料重複。
- **`SettingViewController` 手動備份的 self 生命週期**：「立即備份」觸發的 `Task` 改用 `[weak self]` 並在 `await` 後以 `guard let self` 檢查，避免使用者於備份進行中離開設定頁後，非同步完成的 callback 仍嘗試對已離開畫面的 view controller 呈現結果提示。
- **命名與規格一致性（結論：維持原命名，撤銷「命名不符」的認定）**：先前 review 誤判 `Clock.swift` 的 `BackupClock`／`SystemBackupClock` 與本文件較早版本寫的 `Clock`／`SystemClock` 不一致、須重新命名。實際嘗試重新命名後發現：Swift 標準函式庫本身已定義 `protocol Clock`（`var now: Instant`，來自 Swift Concurrency，無需額外 import 即在任何檔案可見）。若改名為 `Clock`，`clock.now()` 呼叫會被編譯器解析成標準函式庫回傳 `Instant` 的 `now` 屬性，而非本專案回傳 `Date` 的 `now()` 方法，導致型別錯誤。因此正確結論是維持 `BackupClock`／`SystemBackupClock` 命名（1.1 當初的命名本來就是刻意迴避這個衝突），本文件與 `tasks.md` 中所有提及 `Clock`／`SystemClock` 的介面定義段落應理解為 `BackupClock`／`SystemBackupClock` 的筆誤。
- **既有測試修復與補齊**：`AccountViewControllerImportTests` 的「取消匯入」測試目前未實際觸發取消路徑（恆真的無效測試），須修正為可偵測失敗的有效測試；另需為 `SceneDelegate.offerICloudRestoreIfApplicable`／`triggerICloudBackupIfEnabled` 補上單元測試，涵蓋還原提示的顯示/不顯示條件與 `backgroundTaskID` 的正確設值與清除。

### 還原權威來源判斷

`AccountViewController` 登入成功回呼中新增判斷：呼叫 `getLoginAccountEmail()` 取得使用者 email 後，檢查本機 Core Data 是否已有資料（`fetchAllListFromDB()` 非空）。若非空，彈出確認對話框詢問是否匯入本機資料到雲端帳號；使用者確認才呼叫既有的 `uploadListToOnlineDB` 等函式逐筆上傳，取消則本機資料保留但不上傳。登入後續的所有讀寫一律以 Firestore 為權威來源（沿用現有 `getAllListAndStocksFromOnlineDBAndSaveToLocal` 機制），不再參考 iCloud 備份快照內容。

iCloud 備份的還原入口（App 啟動時偵測 iCloud 有快照但本機資料為空、且使用者未登入 Firebase）則呼叫 `ICloudBackupService.restoreLatestSnapshot()`，還原後直接覆蓋本機 Core Data store。

### 登入後的資料還原流向

```
App 啟動
   │
   ▼
使用者是否已登入 Firebase？
   │
   ├── 否 ──────────────────────────────┐
   │                                    ▼
   │                        本機 Core Data 是否為空？
   │                                    │
   │                          ┌── 是 ───┴─── 否 ──┐
   │                          ▼                   ▼
   │                 iCloud 是否有備份快照？    維持現況
   │                          │                （繼續使用本機資料，
   │                    ┌── 是┴─ 否 ──┐          不觸發還原）
   │                    ▼            ▼
   │           提示使用者是否還原   不還原
   │                    │
   │            使用者確認？
   │              ┌── 是┴─ 否 ──┐
   │              ▼             ▼
   │   ICloudBackupService   維持本機空狀態
   │   .restoreLatestSnapshot()
   │   → 覆蓋本機 Core Data store
   │
   └── 是（已登入 Firebase）
                │
                ▼
     一律以 Firestore 為權威來源
     （getAllListAndStocksFromOnlineDBAndSaveToLocal /
       getAllHistoryFromOnlineDBAndSaveToLocal）
     → 寫入本機 Core Data
     → 不讀取、不參考 iCloud 備份快照

【登入當下才會額外檢查一次】
使用者剛完成 Firebase 登入
                │
                ▼
     本機 Core Data 是否已有資料？
                │
        ┌── 是 ─┴─ 否 ──┐
        ▼               ▼
 彈出「是否匯入      跳過確認，
  本機資料到帳號」    直接以 Firestore 為準
  確認對話框
        │
   使用者確認？
   ┌── 是┴─ 否 ──┐
   ▼             ▼
呼叫既有的      保留本機資料但
uploadXxx()     不上傳，往後讀寫
逐筆上傳        仍以 Firestore 為準
到 Firestore
```

**重點**：兩種還原路徑（iCloud 快照還原 / Firebase 登入匯入確認）**互斥、不自動合併**——一旦使用者登入 Firebase，Firestore 永遠贏，iCloud 快照只在「從未登入」的情境下才有意義；登入當下若本機已有資料，一定要使用者明確按下確認才會上傳，不會有任何靜默合併發生。

## Implementation Contract

**行為（Behavior）**：
- App 進入背景時，若本機資料自上次備份後有變動，且距上次備份時間 ≥1 小時，App 會在背景執行視窗內（`beginBackgroundTask`）將 Core Data sqlite store 複製一份快照寫入 iCloud Drive ubiquity container，並更新上次備份時間戳（存於 `UserDefaults`）。
- App 啟動或回到前景時，執行同一組節流判斷；設定頁「立即備份」按鈕呼叫時略過節流判斷，強制執行一次備份。
- 使用者未登入 Firebase、且本機資料為空、且偵測到 iCloud 有備份快照時，App 啟動時提示是否還原；還原會覆蓋本機 Core Data store 為快照內容。
- 使用者登入 Firebase 成功、且本機資料非空時，彈出「是否匯入本機資料到帳號」確認對話框；確認才上傳，取消則不上傳且不刪除本機資料。
- 登入 Firebase 後，資料讀寫一律以 Firestore 為準，不再讀取 iCloud 快照。
- iCloud 備份與 Firebase 登入為兩個獨立的 Settings 開關；兩者皆關閉時，設定頁顯示提醒文字，但不阻擋任何操作。

**介面/資料形狀**：
- `protocol ICloudBackupService { func backupIfNeeded(reason: BackupTriggerReason) async; func restoreLatestSnapshot() async throws; func manualBackupNow() async throws }`
- `enum BackupTriggerReason { case didEnterBackground, appLaunch, manual }`
- `protocol BackupClock { func now() -> Date }`（named to avoid colliding with the Swift standard library's own `protocol Clock`）
- `protocol ICloudAvailabilityChecking { func isICloudAvailable() -> Bool }`
- `protocol BackupDestination { func write(snapshotAt url: URL) throws; func latestSnapshotURL() -> URL? }`
- `URL.storeURL(for:databaseName:) -> URL?`（原本為非 optional，本次改為 optional)
- `NotificationCenter` 通知名稱：`.dataSaveDidFail`（`saveContext` 失敗時發出，`object` 為對應的 `NSError`)

**失敗模式**：
- iCloud 不可用（未登入系統 iCloud 帳號）：`backupIfNeeded` 靜默略過並記錄 log，不拋出錯誤、不影響 App 其他功能。
- App Group 容器取得失敗：視為設定錯誤，`fatalError` 並顯示明確錯誤訊息（entitlement 設定問題）。
- Core Data 存檔失敗：記錄錯誤、發出 `.dataSaveDidFail` 通知，不中斷 App 執行。
- `loadPersistentStores` 遇到已知六種 `CKError`：記錄分類錯誤、不中斷初始化；遇到未知錯誤：維持 `fatalError`。
- 快照 schema 版本與目前執行版本不相容：`restoreLatestSnapshot()` 記錄錯誤並中止還原，不覆蓋本機 store，不讓 App 因 migration 錯誤而在下次啟動時崩潰。
- 備份/還原進行中收到重複觸發：後到的呼叫需被忽略或等待前一個完成（序列化），不得並行寫入同一份快照或 store 檔案。
- `NSFileCoordinator` 協調過程本身失敗（例如檔案被其他 process 鎖定逾時）：`write`/`restoreLatestSnapshot` 記錄錯誤並拋出，不得吞掉錯誤假裝成功。
- 還原完成但 `persistentStoreCoordinator.remove(_:)`／重新 `loadPersistentStores` 失敗：記錄錯誤並視同還原失敗處理，不得讓 App 帶著指向舊檔案的 store 繼續執行。
- 使用者離開設定頁後，先前觸發的手動備份 `Task` 才完成：不得對已釋放或已從畫面移除的 view controller 呈現 alert。

**並行/生命週期補充**：
- `SceneDelegate.backgroundTaskID` 的讀寫（`beginBackgroundTask` 到期 callback 與 `Task` 內賦值）須經同步機制保護，避免跨執行緒 data race。
- `restoreLatestSnapshot()` 執行前須先檢查 `ICloudAvailabilityChecking.isICloudAvailable()`，與 `backupIfNeeded`／`manualBackupNow` 一致。
- 同一 Firebase 帳號在同一 App session 內重複登入/登出：`offerLocalDataImportIfNeeded` 不得對已處理過的匯入請求重複詢問或重複上傳。

**驗收標準**：
- 單元測試：注入 fake `Clock` 驗證節流邏輯在「剛好 1 小時」「59 分鐘」「59 分 59 秒」三種邊界情況下的行為正確。
- 單元測試：注入 fake `ICloudAvailabilityChecking`（回傳 false）驗證 `backupIfNeeded` 不呼叫 `BackupDestination.write`。
- 單元測試：注入 fake `BackupDestination` 驗證「有變動且超過節流時間」才呼叫 `write`，「無變動」或「未超過節流時間」不呼叫。
- 單元測試：驗證 `URL.storeURL` 在 App Group 容器不存在時回傳 `nil` 而非崩潰。
- 手動驗證：於模擬器登出系統 iCloud 帳號後啟動 App，確認不崩潰且本機功能正常。
- 手動驗證：登入 Firebase 帳號且本機已有清單資料時，確認彈出匯入確認對話框；取消後本機資料仍在且未上傳。
- 單元測試：驗證 `BackupDestination.write` 對同一快照檔案連續觸發兩次寫入時，最終檔案內容完整不損毀（模擬中途中斷）。
- 單元測試：驗證 `restoreLatestSnapshot()` 在快照 schema 版本不相容時回傳/拋出可辨識錯誤，且不修改本機 store 檔案。
- 單元測試：驗證連續兩次呼叫 `manualBackupNow()`（不 await 第一次完成）不會造成第二次呼叫觀察到不完整或損毀的快照檔案。
- 手動驗證：於模擬器對本機資料庫寫入資料後立即觸發備份，確認 iCloud 快照包含該筆最新寫入（驗證 WAL 內容已正確合併）。
- 單元測試：以 fake `NSFileCoordinator` 驗證 `write`／`restoreLatestSnapshot` 確實透過協調機制存取檔案，而非直接呼叫 `FileManager`。
- 整合測試：還原完成後立即對 `LocalDBService` 執行一次寫入與讀取，驗證資料正確落在還原後的 store 而非造成錯誤或損毀。
- 程式碼審查 + Thread Sanitizer：確認 `backgroundTaskID` 所有讀寫皆經同步機制保護，執行一次背景備份流程無 data race 警告。
- 單元測試：以 fake `ICloudAvailabilityChecking`（回傳 false）驗證 `restoreLatestSnapshot()` 不呼叫 `BackupDestination.latestSnapshotURL()`。
- 單元測試：同一 session 內第二次呼叫 `offerLocalDataImportIfNeeded` 不再觸發確認對話框或重複呼叫上傳函式。
- 手動驗證：點擊「立即備份」後立即離開設定頁，確認不出現多餘 alert 或 console 警告。
- 全域搜尋 + 編譯驗證：確認 `BackupClock`／`SystemBackupClock` 已重新命名為 `Clock`／`SystemClock`，且既有節流邏輯測試改用新名稱後仍全數通過。
- 單元測試：`AccountViewControllerImportTests` 的取消匯入測試在 handler 未被觸發時會失敗（具備偵錯能力），且驗證 `OnlineDBService` 上傳函式完全未被呼叫。
- 單元測試：新增涵蓋 `offerICloudRestoreIfApplicable`「本機為空且未登入且有快照」「已登入 Firebase 不彈出」兩種情境的測試皆通過。

**範圍界線**：
- 範圍內：`ICloudBackupService` 及其依賴 protocol 的新增、`LocalDBService`／`URL+Extension.swift` 的崩潰修復、`AccountViewController` 登入流程新增匯入確認、`SettingViewController` 說明文字與提醒。
- 範圍外：`BGAppRefreshTask` 系統排程、雙資料源自動合併演算法、Firestore 資料結構變更、多 Firebase 帳號切換情境。

## Risks / Trade-offs

- [App 在背景執行視窗（約 30 秒）內若快照檔案過大導致複製未完成] → 快照僅為本機 sqlite 檔案的檔案層級複製，非逐筆序列化，速度足夠；若使用者資料量未來大幅成長需重新評估，本次先以現有資料量級為基準。
- [使用者從未使用 App 超過節流門檻時間、也未曾進背景（例如一直維持前景執行）] → App 啟動/回前景時的補檢查邏輯與進背景邏輯共用同一節流判斷，只要曾經進背景或重啟過就會觸發，涵蓋率足夠；純粹「App 開一次不關」的極端情境本次不特別處理。
- [移除 `NSPersistentCloudKitContainer` 後，原本依賴即時同步的使用者會感受到「多裝置不再即時同步」的體感差異] → 已在討論階段確認此 App 資料屬性（個人記帳、低頻寫入）不需要即時同步，且 Firestore 已覆蓋跨平台即時同步需求；設定頁說明文字會明確告知使用者此差異。

