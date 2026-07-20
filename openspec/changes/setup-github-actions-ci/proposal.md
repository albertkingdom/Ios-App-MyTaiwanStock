## Why

專案目前完全沒有 CI/CD 機制。每次 push 或開 PR 都無法自動驗證專案是否能成功建置、單元測試是否通過，問題只能等到本機建置或上架前才會被發現，增加了整合風險與除錯成本。專案為 public repo，GitHub Actions 對 public repo 的 macOS runner 免費無限制使用，是最低成本的導入方式。

## What Changes

- 新增 GitHub Actions workflow，於下列時機自動觸發：
  - 對 `mvvm`（預設分支）開 Pull Request 時
  - 對 `mvvm` 分支 push 時
- Workflow 執行內容：
  - 使用 macOS runner（`macos-latest`，內建 Xcode）
  - Resolve Swift Package Manager 依賴（專案透過 SPM 管理 Firebase、GoogleSignIn、Charts、Kingfisher 等第三方套件）
  - 使用 `MyTaiwanStock` scheme、`iphonesimulator` SDK、`CODE_SIGNING_ALLOWED=NO` 建置 App target 與其 extension targets（`StockWidgetExtension`、`LiveActivityExtension`），避免在 CI 中處理簽章憑證
  - 執行 `MyTaiwanStockTests` 單元測試（`xcodebuild test`，destination 指向 iOS Simulator）
  - Build/test 失敗時該次 workflow run 標示為失敗，並可在 GitHub PR 檢查中看到結果
- 新增 workflow 檔案：`.github/workflows/ci.yml`

## Non-Goals

- **不處理程式碼簽章、Archive、上傳 TestFlight 或 App Store**：這次僅聚焦在 build + test 驗證，簽章與發佈流程（fastlane + match）留待後續變更處理。
- **不引入 lint / SwiftLint 等靜態分析工具**：如專案尚未有 lint 設定，本次不新增，避免範圍擴大。
- **不變更現有 Xcode scheme 或 target 設定**：僅新增 workflow 檔案，不修改 `MyTaiwanStock.xcodeproj` 內容。
- **不處理 Debug-only 的第三方登入（Google Sign-In／Firebase）在 CI 環境的執行期驗證**：`GoogleService-Info.plist` 已存在於版本控制中，足以讓專案「建置」成功；不驗證需要真實網路/帳號的執行期功能（例如登入流程），因為單元測試不涉及這些外部服務的整合測試。
- **不新增 Xcode Cloud 或其他 CI 平台**：已與使用者確認採用 GitHub Actions。

## Capabilities

### New Capabilities

- `ci-build-workflow`: PR 與 push 時自動用 GitHub Actions 建置 App 與其 extension targets，並執行單元測試，於 GitHub 檢查（checks）中回報成功/失敗結果。

### Modified Capabilities

(none)

## Impact

- Affected specs: `ci-build-workflow`（新增）
- Affected code:
  - New: `.github/workflows/ci.yml`
  - Modified: (none)
  - Removed: (none)
