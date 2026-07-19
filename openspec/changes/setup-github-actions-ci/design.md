## Context

專案是純 iOS App（`MyTaiwanStock.xcodeproj`），包含三個非測試 target（`MyTaiwanStock`、`StockWidgetExtension`、`LiveActivityExtension`）與一個測試 target（`MyTaiwanStockTests`，內含 3 個測試檔案：`testOverViewCalculator.swift`、`TestStockListViewModel.swift`、`ValidInputServiceTest.swift`）。依賴管理透過 Swift Package Manager，套件包含 Firebase、GoogleSignIn、Charts、Kingfisher、MessageKit 等約 20 個套件。`GoogleService-Info.plist` 已提交在版本控制中（`MyTaiwanStock/GoogleService-Info.plist`），因此建置階段不需要額外注入 Firebase 設定檔。

現有 shared scheme `MyTaiwanStock.xcscheme` 已啟用 Test Action（Debug configuration），可直接透過 `xcodebuild test` 執行。目前完全沒有任何 CI 設定（無 `.github/workflows`、無 Xcode Cloud、無可執行的 Fastfile）。

Repo 為 public，GitHub Actions 對 public repo 的 hosted macOS runner 無使用量限制與費用。

## Goals / Non-Goals

**Goals:**

- 在 PR 與 push 到 `mvvm` 分支時，自動驗證專案可成功建置（App + extension targets）與單元測試通過
- 避免在 CI 中處理程式碼簽章憑證，降低導入複雜度
- 使用 GitHub 原生機制（Actions）呈現建置/測試結果，讓 PR 頁面直接可見成功/失敗狀態
- 合理使用 SPM 套件快取，縮短重複執行的建置時間

**Non-Goals:**

- 不做 Archive、簽章、TestFlight/App Store 上傳（見 proposal Non-Goals）
- 不引入 SwiftLint 或其他靜態分析
- 不修改現有 `.xcodeproj`、scheme 或 target 設定
- 不新增 UI Test 或整合測試（僅執行既有的 unit test target）

## Decisions

### 使用 GitHub Actions `macos-latest` runner，而非自架 runner 或 Xcode Cloud

原因：public repo 使用 GitHub-hosted macOS runner 完全免費，`macos-latest` 內建多個 Xcode 版本可透過 `xcode-select` 切換，不需額外基礎設施維運。使用者已於討論中確認選擇 GitHub Actions（相較 Xcode Cloud，彈性更高、無 25 小時/月的用量上限疑慮）。

### 建置目的地固定為 iOS Simulator（`platform=iOS Simulator,name=iPhone 16`），並停用程式碼簽章

原因：這次範圍明確排除簽章/發佈（見 Non-Goals）。對 simulator 建置設定 `CODE_SIGNING_ALLOWED=NO`，可完全略過憑證與 provisioning profile，避免在沒有 Apple Developer 憑證匯入的情況下建置失敗。選擇具體裝置名稱（`iPhone 16`）而非 `generic/platform=iOS Simulator`，是因為 `xcodebuild test` 需要一個可實際啟動的 simulator 目的地；不指定 OS 版本，讓 xcodebuild 依 runner 上安裝的最新可用 runtime 自動選擇，避免因 Xcode 版本更新導致寫死的 OS 版本號失效。

### 單一 workflow job 依序執行 build 與 test（先 build 三個 target，再對 `MyTaiwanStock` scheme 跑 test）

原因：專案規模小（單一 app + 2 個 extension），拆分多個平行 job 的價值不高，且會重複付出 SPM resolve 與 checkout 的固定成本。使用單一 job 以 `xcodebuild build` 分別建置三個 non-test target，再用 `xcodebuild test` 執行測試，邏輯簡單、log 易讀。

### 使用 `actions/cache` 快取 SPM 依賴（`~/Library/Developer/Xcode/DerivedData/**/SourcePackages` 與 `.build`）

原因：專案有約 20 個 SPM 套件（含 Firebase 全家桶），首次 resolve 耗時較長。以 `Package.resolved` 的雜湊值作為 cache key，可在依賴未變動時大幅縮短後續 workflow 執行時間。

### Workflow 觸發條件：`pull_request`（目標分支 `mvvm`）與 `push`（分支 `mvvm`）

原因：`mvvm` 是目前的預設分支（`origin/HEAD -> origin/mvvm`）。對 PR 與對預設分支的 push 都做驗證，涵蓋「合併前檢查」與「合併後確認」兩種情境，符合 proposal 中「PR / push 時自動 build」的目標。

## Implementation Contract

**行為（Behavior）：**
- 任何人對 `mvvm` 分支開 PR，或直接 push 到 `mvvm`，GitHub 會自動觸發名為 `CI` 的 workflow（檔案：`.github/workflows/ci.yml`）
- Workflow 在 PR 頁面的 Checks 區塊顯示執行狀態（queued → in progress → success/failure）
- 若 SPM 套件 resolve 失敗、任一 target 建置失敗、或任一單元測試失敗，該次 workflow run 標示為 failure，PR 的 merge 檢查會顯示未通過（即使不強制阻擋 merge，也會清楚可見）
- 若 build 與 test 全部成功，該次 workflow run 標示為 success

**Workflow 結構（Interface）：**
- 檔案路徑：`.github/workflows/ci.yml`
- `name: CI`
- `on.pull_request.branches: [mvvm]`，`on.push.branches: [mvvm]`
- `jobs.build-and-test.runs-on: macos-latest`
- Steps（依序）：
  1. `actions/checkout@v4`
  2. 選擇 Xcode 版本（`xcode-select -p` 確認後如需固定版本可用 `sudo xcode-select -s /Applications/Xcode_<version>.app`；若無特殊需求則使用 runner 預設 Xcode，不额外指定）
  3. `actions/cache@v4`：key 依 `Package.resolved` 內容雜湊（`hashFiles('**/Package.resolved')`），快取路徑涵蓋 SPM 套件下載目錄
  4. Resolve 套件：`xcodebuild -resolvePackageDependencies -project MyTaiwanStock.xcodeproj`
  5. Build App target：`xcodebuild build -project MyTaiwanStock.xcodeproj -scheme MyTaiwanStock -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`
  6. Build extension targets（`StockWidgetExtension`、`LiveActivityExtension`）：以各自 shared scheme 或以 `-target` 方式建置，同樣加上 `CODE_SIGNING_ALLOWED=NO`
  7. Run tests：`xcodebuild test -project MyTaiwanStock.xcodeproj -scheme MyTaiwanStock -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`

**失敗模式（Failure modes）：**
- SPM resolve 失敗（例如套件來源不可達）→ step 4 失敗，後續 step 不執行，workflow 標示 failure，log 顯示 xcodebuild 的 resolve 錯誤輸出
- 建置失敗（語法錯誤、簽章相關設定殘留導致仍要求憑證等）→ 對應 build step 失敗並中止，log 保留完整 `xcodebuild` 輸出供除錯
- 測試失敗（assertion 失敗或 crash）→ test step 標示 failure，xcodebuild 會輸出失敗的測試案例名稱
- 這些失敗都不會靜默；GitHub Actions 預設任何 step 非 0 結束碼即中止 job 並標示 run 為 failure

**驗收標準（Acceptance criteria）：**
- 在此分支開一個測試 PR 或 push 一個小改動，於 GitHub Actions 頁面確認 `CI` workflow 被觸發並執行
- 確認 workflow 最終狀態為 success（在依賴、簽章設定正確的前提下）
- 手動製造一個會失敗的情境（例如暫時讓某個測試斷言失敗）驗證 workflow 正確回報 failure，再改回正確狀態

**範圍邊界（Scope boundaries）：**
- 範圍內：新增 `.github/workflows/ci.yml`；驗證 build 與 test 能在 CI 中跑通
- 範圍外：修改 `.xcodeproj`/scheme 設定、新增簽章/上傳流程、新增 lint、調整既有測試內容、處理 `.ipa` 檔案是否應存在於版本控制中（此為既有狀態，不在本次變更範圍）

## Risks / Trade-offs

- [風險] `iPhone 16` 模擬器裝置名稱未來可能在新版 Xcode 中被移除或改名，導致 destination 找不到裝置而失敗 → [緩解] 若發生，改用當下 runner 可用清單中存在的裝置名稱（`xcrun simctl list devicetypes`），或改用 `platform=iOS Simulator,name=Any iOS Simulator Device` 等更寬鬆寫法
- [風險] GitHub-hosted `macos-latest` runner 內建的 Xcode 版本會隨時間推進，可能與本機開發環境使用的 Xcode 版本不一致，導致「本機過、CI 不過」或反之 → [緩解] 若後續需要穩定性，可在 workflow 中明確指定 Xcode 版本（`xcode-select -s`），此變更先不鎖定版本，觀察實際執行狀況再決定
- [風險] SPM 套件數量多（含 Firebase），首次無快取時 resolve 可能耗時數分鐘 → [緩解] 已透過 Decisions 中的 `actions/cache` 設計快取依賴，僅首次或 `Package.resolved` 變動時需要完整下載
- [風險] `CODE_SIGNING_ALLOWED=NO` 對某些 target 若有依賴簽章相關的 build phase script（例如需要 entitlements 處理）可能仍會出錯 → [緩解] 若發生，於 apply 階段實際執行 workflow 觀察錯誤訊息，針對特定 target 額外加上 `CODE_SIGN_IDENTITY=""` 或 `-skipPackagePluginValidation` 等參數調整
