## 1. 手動備份錯誤回報（Periodic iCloud snapshot backup）

- [x] 1.1 落實「Periodic iCloud snapshot backup」需求中「Manual backup fails when iCloud is unavailable」情境：`ICloudBackupService.manualBackupNow()` 在 `availabilityChecking.isICloudAvailable()` 回傳 `false` 時，改為 `throw ICloudBackupServiceError.iCloudUnavailable`，取代目前的靜默 `return`；驗證方式：單元測試以 fake `ICloudAvailabilityChecking`（回傳 `false`）呼叫 `manualBackupNow()`，斷言拋出 `ICloudBackupServiceError.iCloudUnavailable` 且 `BackupDestination.write` 未被呼叫。
- [x] 1.2 `SettingViewController.manualBackupTapped()` 捕捉 `ICloudBackupServiceError.iCloudUnavailable` 時，顯示「尚未登入 iCloud，無法備份」錯誤訊息（而非目前統一顯示 `error.localizedDescription` 的通用文字），其餘錯誤類型維持顯示 `error.localizedDescription`；驗證方式：程式碼審查確認 catch block 對 `iCloudUnavailable` 有專屬分支，並提供對應的 `LocalizedError.errorDescription` 或 switch 判斷。

## 2. 設定頁狀態提示（Independent optional toggles with combined-off warning）

- [x] 2.1 落實「Independent optional toggles with combined-off warning」需求中「iCloud backup toggle enabled but device not signed into iCloud」情境：`SettingViewController.section0FooterText()` 判斷是否顯示「未啟用任何備份，資料遺失將無法復原」風險提示的條件，從單純檢查 `syncPreference == .iCloud` 改為同時檢查 `ICloudAvailabilityChecking.isICloudAvailable()`：開關已開但裝置未登入 iCloud 時，視為與「開關關閉」相同的風險狀態；驗證方式：單元測試以 fake `ICloudAvailabilityChecking`（回傳 `false`）與 `syncPreference = .iCloud` 的組合呼叫 `section0FooterText()`，斷言回傳文字包含風險提示字串。
- [x] 2.2 在「開關已開、但裝置未登入 iCloud」這個狀態下，`section0FooterText()` 額外附加「iCloud 備份要求裝置需先登入 iCloud」的說明文字，與「開關關閉」的一般風險提示區分開來；驗證方式：單元測試比對「開關關閉」與「開關開啟但未登入 iCloud」兩種情況下 `section0FooterText()` 的回傳文字不相同，且後者包含「登入 iCloud」相關字樣。

## 3. 回歸驗證

- [x] 3.1 執行既有 `ICloudBackupServiceTests` 與新增的測試，確認全數通過；驗證方式：執行 `xcodebuild test` 對應 scheme，確認 build 與測試結果為 success。
- [x] 3.2 手動驗證：模擬器登出系統 iCloud 帳號、開啟 App 內「iCloud 備份」開關、點擊「立即備份」，確認顯示失敗訊息而非「已完成備份到 iCloud」；並確認設定頁出現「尚未登入 iCloud」相關提示文字；驗證方式：於模擬器實際操作並記錄畫面文字。
