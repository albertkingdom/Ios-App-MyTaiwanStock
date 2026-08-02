## Why

目前 App 使用 `NSPersistentCloudKitContainer` 對 iCloud 做即時鏡射同步，同時又透過 `OnlineDBService`／`NetworkServiceImpl` 對 Firebase Firestore 做跨平台（含 Android）同步，兩條同步路徑同時寫入同一份 Core Data store，造成資料流向糾纏、還原邏輯不明確,並且即時 CloudKit 鏡射本身帶來多個崩潰風險（容器初始化未檢查 iCloud 可用性、存檔失敗直接 `fatalError`、CKError 分類處理不完整）。App 已有 Firebase 作為跨平台帳號後端，iCloud 不需要、也不該再承擔即時同步的角色，應降級為單機定時備份，並明確定義還原時的資料權威來源。

## What Changes

- iCloud 從 `NSPersistentCloudKitContainer` 即時鏡射，改為定時快照備份到 iCloud Drive ubiquity container，觸發時機為：App 進背景時（有資料變動且距上次備份 ≥1 小時）、App 啟動/回前景時補檢查、設定頁提供手動「立即備份」按鈕。
- 修復三個既有崩潰風險：`LocalDBService` 初始化容器前未檢查 iCloud 可用性、`URL+Extension.swift` 的 App Group 容器 URL 取得失敗時直接 `fatalError`、`LocalDBService.saveContext()` 存檔失敗直接 `fatalError`；並補齊 `loadPersistentStores` 對常見 CKError（`.notAuthenticated`、`.networkUnavailable`、`.serverRecordChanged` 等）的分類處理，全部改為記錄錯誤並讓 App 可繼續運作，不再直接崩潰。
- 明確定義還原（restore）的資料權威來源：使用者若從未登入 Firebase，新裝置/重灌後可從 iCloud 備份快照還原；使用者一旦登入 Firebase，Firestore 永遠是還原資料的權威來源，不再參考 iCloud 快照內容。
- 登入 Firebase 當下若偵測本機已有資料（可能來自先前的 iCloud 備份還原），**不自動合併**，改為跳出提示，由使用者明確確認是否要把本機資料匯入到雲端帳號。
- Firebase 登入與 iCloud 備份維持各自獨立、皆為 optional，不互相依賴；兩者都停用時，設定頁顯示風險提醒文字（非強制阻擋)。
- 設定頁（`SettingViewController`）針對「iCloud 備份」與「Firebase 帳號登入」兩個區塊各自新增說明文字，並在兩者都關閉時顯示「未啟用任何備份或跨裝置同步，資料遺失將無法復原」的提醒。

## Non-Goals (optional)

- 不處理「使用者已登入 Firebase 後，又想切換不同 Firebase 帳號」的資料合併情境，維持現有行為。
- 不實作雙資料源（iCloud 快照 + 既有 Firestore 雲端資料）自動合併演算法；合併一律要求使用者明確確認匯入，不做智慧合併。
- 不新增 `BGAppRefreshTask` 系統排程背景喚醒備份（僅列為未來加分項），本次僅實作 App 生命週期事件觸發（進背景／啟動／手動）。
- 不變更 Firebase Firestore 端的資料結構（collection 名稱、欄位）。

## Capabilities

### New Capabilities

- `icloud-backup`: iCloud 定時備份機制——觸發時機（進背景/啟動/手動）、備份節流規則、快照寫入 iCloud Drive ubiquity container、初始化與存檔失敗時的優雅錯誤處理（取代原本的 `fatalError`）、設定頁備份開關與說明文字。

### Modified Capabilities

- `account-login`: 登入 Firebase 成功後，若偵測本機已有資料，新增「提示使用者確認是否匯入本機資料」的需求；並新增「登入後 Firestore 為還原資料權威來源，不自動合併 iCloud 快照」的需求。

## Impact

- Affected specs: `icloud-backup`（新增）、`account-login`（修改)
- Affected code:
  - Modified:
    - MyTaiwanStock/Util/LocalDBService.swift
    - MyTaiwanStock/Util/URL+Extension.swift
    - MyTaiwanStock/Util/UserPreferences.swift
    - MyTaiwanStock/Util/OnlineDBService.swift
    - MyTaiwanStock/Repository/NetworkServiceImpl.swift
    - MyTaiwanStock/View Controller/SettingViewController.swift
    - MyTaiwanStock/View Controller/AccountViewController.swift
  - New:
    - MyTaiwanStock/Util/ICloudBackupService.swift
