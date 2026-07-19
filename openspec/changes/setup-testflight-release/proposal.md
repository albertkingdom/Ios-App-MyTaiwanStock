## Why

專案已經有 CI（`.github/workflows/ci.yml`）驗證 build 與 test，但發佈 beta 版本給測試者仍完全依賴手動流程：本機打包、手動簽章、手動上傳 App Store Connect，容易因為忘記遞增 build number、簽章設定錯誤等問題卡關，也沒有留下可重複執行、可交接的發佈紀錄。`fastlane/report.xml` 顯示過去確實手動跑過一次 `build_app`，但沒有留下 `Fastfile`，代表發佈流程目前無法重現。導入 GitHub Actions + fastlane 的自動化 TestFlight 發佈流程，讓每次發 beta 只需觸發一個 workflow，取代手動打包上傳。

## What Changes

- 新增獨立的 GitHub Actions workflow（`workflow_dispatch` 手動觸發），串接以下步驟：
  - 用 fastlane match 從既有的 private repo（`github.com/albertkingdom/ios-signing`，同一開發者帳號下已在使用的 match 憑證庫）抓取/安裝 App Store distribution 憑證，並為 MyTaiwanStock 新建專屬的 provisioning profile（match 私有 repo 存取憑證存於 GitHub Secrets）
  - 自動遞增 `CURRENT_PROJECT_VERSION`（build number），避免每次上傳撞號
  - 用 fastlane `gym`（`build_app`）以 App Store distribution method Archive 並 export IPA
  - 用 fastlane `pilot`（透過 App Store Connect API Key 驗證，不使用帳密登入）上傳 IPA 到 TestFlight
- **BREAKING**：`MyTaiwanStock`、`StockWidgetExtension`、`LiveActivityExtension` 三個 target 的 `CODE_SIGN_STYLE` 從 `Automatic` 改為 `Manual`，並指定 match 產生的 provisioning profile，這是讓 fastlane match 生效的必要條件，會改變本機 Xcode 簽章行為（開發者本機日後也需要透過 `fastlane match development` 取得憑證，不能再依賴 Xcode 自動管理）
- 新增 `fastlane/Fastfile`、`fastlane/Appfile`、`fastlane/Matchfile`
- 新增 GitHub Secrets：App Store Connect API Key（.p8 內容、Key ID、Issuer ID）、match 私有 repo 存取憑證、match 加密密碼
- 新增 `.github/workflows/testflight.yml`

## Capabilities

### New Capabilities

- `testflight-release-workflow`: 透過手動觸發的 GitHub Actions workflow，自動完成簽章、遞增 build number、Archive、匯出 IPA、上傳 TestFlight 的完整發佈流程。

### Modified Capabilities

(none)

## Impact

- Affected specs: `testflight-release-workflow`（新增）
- Affected code:
  - New: `.github/workflows/testflight.yml`, `fastlane/Fastfile`, `fastlane/Appfile`, `fastlane/Matchfile`
  - Modified: `MyTaiwanStock.xcodeproj/project.pbxproj`（三個 target 的 `CODE_SIGN_STYLE`、`PROVISIONING_PROFILE_SPECIFIER` 等簽章相關設定）
  - Removed: (none)
