## 1. Workflow 檔案建立

- [x] 1.1 建立 `.github/workflows/ci.yml`，設定 `name: CI`，並設定觸發條件為「Automatic build and test on pull requests」（`on.pull_request.branches: [mvvm]`）與「Automatic build and test on push to default branch」（`on.push.branches: [mvvm]`），對應設計決策「Workflow 觸發條件：`pull_request`（目標分支 `mvvm`）與 `push`（分支 `mvvm`）」。驗證方式：檢視 workflow YAML 內容，確認 `on` 區塊同時包含 `pull_request`（`branches: [mvvm]`）與 `push`（`branches: [mvvm]`）。
- [x] 1.2 在 workflow 中設定單一 job `build-and-test`，`runs-on: macos-latest`，對應設計決策「使用 GitHub Actions `macos-latest` runner，而非自架 runner 或 Xcode Cloud」與「單一 workflow job 依序執行 build 與 test（先 build 三個 target，再對 `MyTaiwanStock` scheme 跑 test）」。驗證方式：檢視 YAML，`jobs.build-and-test.runs-on` 值為 `macos-latest`，且所有 build/test step 都在同一個 job 內依序排列。

## 2. 依賴快取與 Resolve

- [x] 2.1 新增 `actions/checkout@v4` step 與 `actions/cache@v4` step，以 `hashFiles('**/Package.resolved')` 作為 cache key 快取 SPM 套件下載目錄，對應設計決策「使用 `actions/cache` 快取 SPM 依賴（`~/Library/Developer/Xcode/DerivedData/**/SourcePackages` 與 `.build`）」。驗證方式：檢視 YAML 中 cache step 的 `key` 使用 `hashFiles('**/Package.resolved')`，`path` 涵蓋 SPM 套件快取目錄。
- [ ] 2.2 新增 resolve 依賴 step，執行 `xcodebuild -resolvePackageDependencies -project MyTaiwanStock.xcodeproj`，實現規格「Build failure is surfaced, not silenced」中 dependency resolution 失敗情境。驗證方式：在此分支的 PR 上實際觸發一次 workflow run，確認此 step 成功執行且無錯誤（可於 GitHub Actions 頁面檢視該 step 的 log 顯示 resolve 成功訊息）。

## 3. Build 三個 Target（不需簽章）

- [ ] 3.1 新增 build step，以 `xcodebuild build -scheme MyTaiwanStock -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` 建置 App target，實現規格「Build without code signing」與設計決策「建置目的地固定為 iOS Simulator（`platform=iOS Simulator,name=iPhone 17`），並停用程式碼簽章」。驗證方式：觸發 workflow run，確認該 step 結束碼為 0 且 log 無簽章相關錯誤（不出現 "requires a provisioning profile" 等訊息）。
- [ ] 3.2 新增 build step，建置 `StockWidgetExtension` target（同樣加上 `CODE_SIGNING_ALLOWED=NO`），驗證方式：觸發 workflow run，確認對應 step 結束碼為 0。
- [ ] 3.3 新增 build step，建置 `LiveActivityExtension` target（同樣加上 `CODE_SIGNING_ALLOWED=NO`），驗證方式：觸發 workflow run，確認對應 step 結束碼為 0。
- [ ] 3.4 驗證任一 target 編譯錯誤時 workflow 會正確標示失敗，實現規格「Build failure is surfaced, not silenced」中「A target fails to compile」情境。驗證方式：暫時在任一 target 的原始碼中引入一個語法錯誤並 push 到測試分支觀察對應 build step 失敗、workflow run 標示為 failure，log 中含 `xcodebuild` 錯誤輸出；確認後還原變更。

## 4. 執行單元測試並回報結果

- [ ] 4.1 新增 test step，以 `xcodebuild test -scheme MyTaiwanStock -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` 執行 `MyTaiwanStockTests`，實現規格「Unit test execution and reporting」。驗證方式：觸發 workflow run，確認 test step log 顯示 `MyTaiwanStockTests` 內三個測試檔案（`testOverViewCalculator`、`TestStockListViewModel`、`ValidInputServiceTest`）的測試案例皆被執行且全部通過，workflow run 最終狀態為 success。
- [ ] 4.2 驗證單一測試失敗時 workflow 會正確標示失敗並在 log 顯示失敗案例名稱，實現規格「Unit test execution and reporting」中「A unit test fails」情境。驗證方式：暫時修改任一測試使其斷言失敗並 push 到測試分支，觀察 workflow run 標示為 failure 且 log 中出現該測試案例名稱；確認後還原變更。

## 5. 端對端驗證

- [ ] 5.1 在此分支上開一個 Pull Request 指向 `mvvm`，確認 GitHub Actions Checks 區塊出現名為 `CI` 的 workflow run 並最終顯示成功（綠勾），驗證規格「Automatic build and test on pull requests」與「Automatic build and test on push to default branch」的組合行為。驗證方式：直接於 GitHub PR 頁面觀察 Checks 狀態為 success。
