## Why

使用者在 App 內開啟「iCloud 備份」開關時，目前完全沒有檢查裝置本身是否已登入 iCloud（`FileManager.default.ubiquityIdentityToken`）。若裝置未登入 iCloud，`ICloudBackupService.manualBackupNow()` 會靜默略過寫入快照並直接 return（不 throw），但 `SettingViewController` 的「立即備份」按鈕仍會顯示「已完成備份到 iCloud。」的成功訊息；同時設定頁 `section0FooterText()` 判斷是否顯示「未啟用任何備份，資料遺失將無法復原」風險提示時，只看開關狀態（`syncPreference == .iCloud`），不看實際的 iCloud 可用性，導致這個警告也不會出現。使用者因此會誤以為資料已受保護，實際上從未真正備份過，一旦刪除 App 或換裝置即會遺失資料且求助無門。

## What Changes

- `ICloudBackupService.manualBackupNow()` 在 iCloud 不可用時改為 throw `ICloudBackupServiceError.iCloudUnavailable`（沿用既有 error case），取代目前的靜默 `return`。
- `SettingViewController.manualBackupTapped()` 捕捉到 `iCloudUnavailable` 時顯示對應錯誤訊息（例如「尚未登入 iCloud，無法備份」），不再顯示「已完成備份到 iCloud。」的成功訊息。
- `SettingViewController.section0FooterText()` 判斷「是否顯示未啟用任何備份風險提示」的條件，除了現有的 `syncPreference == .iCloud` 開關狀態外，改為同時檢查 `ICloudAvailabilityChecking.isICloudAvailable()`；開關已開但裝置實際未登入 iCloud 時，一樣視為「備份未生效」並顯示風險提示。
- 設定頁在「開關已開、但裝置未登入 iCloud」這個狀態下，額外顯示明確文字（例如「已開啟，但裝置尚未登入 iCloud，備份暫不會執行」），與純粹「開關關閉」的情況區分開來，避免使用者誤判。

## Non-Goals (optional)

- 不新增自動跳轉系統設定頁引導使用者登入 iCloud 的流程，本次僅修正文字與錯誤回報，不做導引式 UX。
- 不改變 `backupIfNeeded(reason:)`（App 進背景/啟動觸發的自動備份路徑）在 iCloud 不可用時的既有靜默略過行為——背景自動備份仍應安靜失敗、不彈窗打擾使用者。本次只修正「使用者主動點擊立即備份」與「設定頁風險提示顯示邏輯」這兩個會直接誤導使用者判斷的路徑。
- 不修改 `restoreLatestSnapshot()` 的錯誤處理，該函式已經在 iCloud 不可用時正確 throw `iCloudUnavailable`，不在本次範圍內。

## Capabilities

### Modified Capabilities

- `icloud-backup`: 新增「裝置未登入 iCloud 時，手動備份必須明確回報失敗（不得顯示成功訊息）、設定頁的備份風險提示必須反映裝置實際 iCloud 可用狀態（不能只看使用者開關）」的需求。

## Impact

- Affected specs: icloud-backup
- Affected code:
  - Modified: MyTaiwanStock/Util/ICloudBackupService.swift
  - Modified: MyTaiwanStock/View Controller/SettingViewController.swift
