## Context

專案已有 `.github/workflows/ci.yml`（build + unit test，PR/push 到 `mvvm` 時觸發，使用模擬器 ad-hoc 簽章、不需要真實憑證）。這次要新增的是「發佈到 TestFlight」的獨立流程，跟既有 CI 完全不同：CI 只需要模擬器建置，TestFlight 發佈需要真正的 App Store distribution 簽章、Archive、匯出 IPA、上傳 App Store Connect。

專案有三個需要簽章的 target：`MyTaiwanStock`（app，bundle id `com.a2006mike.MyTaiwanStock`）、`StockWidgetExtension`（`com.a2006mike.MyTaiwanStock.StockWidget`）、`LiveActivityExtension`（`com.a2006mike.MyTaiwanStock.LiveActivity`），皆屬於同一個 `DEVELOPMENT_TEAM = UZ2Z639589`，目前都是 `CODE_SIGN_STYLE = Automatic`。

使用者已有一個既有的 private repo `github.com/albertkingdom/ios-signing`，是標準的 fastlane match 憑證庫（README 為 match 產生的樣板文字），目前存有：
- `certs/development`、`certs/distribution`（已有 distribution 憑證，因為同一 Apple Developer Team 下的 distribution 憑證可跨 app 共用）
- `profiles/appstore/AppStore_com.a2006mike.MyBusMapSwiftUI.mobileprovision`（另一個 app 的 provisioning profile，MyTaiwanStock 目前還沒有自己的 profile）
- `match_version.txt` 記錄 fastlane 版本 `2.231.1`

`fastlane/` 目錄目前只有一個舊的 `report.xml`（記錄過去手動跑過 `default_platform` → `xcversion` → `increment_build_number` → `build_app`），沒有 `Fastfile`/`Appfile`/`Matchfile`，代表這個流程從未被固化成可重複執行的設定。

`MARKETING_VERSION = 1.0`、`CURRENT_PROJECT_VERSION = 1`。

使用者不確定自己是否已有 App Store Connect API Key（.p8），需要在流程早期加入「檢查/建立 API Key」的任務。

## Goals / Non-Goals

**Goals:**

- 用一個可手動觸發（`workflow_dispatch`）或以 `v*` git tag push 自動觸發的 GitHub Actions workflow，完成「簽章 → 遞增 build number → Archive → 匯出 IPA → 上傳 TestFlight」的完整流程
- 沿用既有的 `ios-signing` match 憑證庫，不重新建立簽章基礎設施
- 所有跟 Apple/App Store Connect 的驗證都用 API Key（.p8），不使用帳號密碼或雙因素登入互動
- 三個需要簽章的 target 從 Automatic 改為 Manual signing，確保 CI 環境（無互動、無 Xcode GUI）能穩定簽章

**Non-Goals:**

- 不做正式上架 App Store（`release` lane、App Store 審核送出）
- 不管理 TestFlight tester 群組、邀請名單的細節（沿用 App Store Connect 網頁上既有設定）
- 不自動產生 release note／what's new 文字（先留空或用固定文字，由使用者之後在 App Store Connect 網頁手動補上）
- 不處理 `feature/live-activities` 之外分支的發佈（只從觸發 workflow 當下的分支/commit 發佈，不引入額外的分支保護或發佈分支策略）
- 不修改既有 `.github/workflows/ci.yml` 的內容或觸發條件

## Decisions

### 沿用既有的 `github.com/albertkingdom/ios-signing` 作為 match storage repo，而非新建 repo

原因：這個 repo 已經是同一開發者帳號、同一 Apple Developer Team 底下在用的 match 憑證庫，已經有 distribution 憑證可以共用（match 的 distribution 憑證是綁在 Apple Developer Team 而非單一 app，同一 team 下的多個 app 可以共用同一張憑證）。只需要讓 match 幫 MyTaiwanStock 產生一組新的 provisioning profile 存進這個 repo，不需要重新走一次憑證簽發流程。風險：需要先確認這個 repo 存放的 distribution 憑證確實屬於 `UZ2Z639589` 這個 team（與 MyTaiwanStock 一致），否則 match 會失敗或簽出無法用於此 app 的憑證，此驗證排入 tasks 的早期步驟。

### `CODE_SIGN_STYLE` 從 Automatic 改為 Manual，三個 target 都改

原因：fastlane match 搭配 CI 這種無人值守環境，必須用 Manual signing 明確指定 provisioning profile，Automatic signing 會嘗試連線 Apple ID 互動式產生憑證，在 CI 裡無法運作。三個 target（`MyTaiwanStock`、`StockWidgetExtension`、`LiveActivityExtension`）都需要各自的 App Store provisioning profile，因為都各自有獨立的 bundle id。這個改動是 **BREAKING**：改成 Manual 後，本機開發者用 Xcode 開啟專案時不會再自動處理簽章，需要先在本機跑 `fastlane match development` 取得對應的開發憑證，否則本機 build 會因為找不到 provisioning profile 失敗。

### App Store Connect 驗證一律使用 API Key（.p8 + Key ID + Issuer ID），不使用 Apple ID 帳密

原因：CI 環境無法完成雙因素驗證（2FA）互動，且帳密登入的 session token 在 CI 裡不穩定、容易過期。API Key 是 Apple 官方建議的 CI/CD 驗證方式，沒有 2FA 互動需求，且可以精確控制權限範圍（Admin/App Manager 等角色）。fastlane 的 `app_store_connect_api_key` action 讀取三個環境變數（Key ID、Issuer ID、.p8 內容），供後續 `match`、`pilot`、`upload_to_testflight` 等 action 共用同一組驗證。

### Workflow 觸發方式：`workflow_dispatch`（手動觸發）與 `v*` git tag push（自動觸發）並存，不綁定固定分支的 push

原因：使用者希望自己控制「什麼時候真的要發一個 beta 版本」，不希望每次對某個分支 push 都自動發布到 TestFlight（分支 push 太頻繁，容易因為忘記這件事而在有 bug 的 commit 上自動發出 beta）。`workflow_dispatch` 讓使用者在 GitHub Actions 頁面上手動點擊觸發，可以選擇要發佈的分支/commit，是最基本、最安全的觸發方式。

額外加上 `push` 觸發、限定符合 `v*` 格式的 tag（例如 `v1.0.1`）：打 tag 本身就是一個刻意的動作（不像分支 push 那樣每個 commit 都會發生），可以兼顧「自動化上傳」與「使用者仍然決定何時發版」兩個需求，且 tag 名稱可以順便作為這次發佈對應的版本紀錄。**不**採用「push 到 `release` 分支自動觸發」的作法，因為分支上的每個 commit 都會觸發，遠比 tag push 頻繁，risk 更高。兩種觸發方式（手動、tag push）共用同一個 job 定義，行為完全一致，只差在觸發條件。

### tag push 觸發時，限定 tag 必須指向 `release` 分支歷史中的 commit

原因：這個 repo 已經有一個既有的 `release` 分支（目前存在，`origin/release`），推測是使用者原本手動維護的「準備發版」分支。如果任何分支都能打 `v*` tag 觸發 TestFlight 發佈，容易發生「不小心從 `mvvm` 或某個 feature branch 打了 tag」而發出未經確認的 beta。加上這道檢查後，tag push 觸發時 workflow 第一步就驗證該 tag 指向的 commit 是否在 `origin/release` 的祖先鏈裡（`git merge-base --is-ancestor <tag-commit> origin/release`），不符合就立刻失敗、不執行任何簽章/上傳動作。`workflow_dispatch` 手動觸發**不**受此限制（使用者手動選分支觸發時已經是刻意行為，不需要額外限制），只有 tag push 這個自動觸發路徑需要這道保護。

### 自動遞增 `CURRENT_PROJECT_VERSION`，使用 fastlane `increment_build_number` 搭配 App Store Connect 最新 build number 查詢

原因：`CURRENT_PROJECT_VERSION` 目前固定為 `1`，如果每次上傳都不遞增，會因為 build number 重複被 App Store Connect 拒絕上傳。使用 fastlane 的 `latest_testflight_build_number` action 讀取 App Store Connect 上該 app 目前最新的 build number，再用 `increment_build_number` 設成「該數字 + 1」，而不是單純遞增本機 `project.pbxproj` 裡的數字，因為本機數字可能因為多人協作、多分支而落後於 App Store Connect 上實際已上傳的 build number，用「查詢 + 遞增」可以避免跟已上傳過的 build number 衝突。此步驟只在 CI workflow 執行時對 checkout 出來的暫存副本生效，**不會**把新的 build number commit 回專案的 git 歷史（維持 stateless CI，避免 workflow 自己 push commit 回 repo 造成的循環觸發或權限複雜度）。

## Implementation Contract

**行為（Behavior）：**
- 使用者在 GitHub Actions 頁面手動觸發 `TestFlight Release` workflow（`workflow_dispatch`），選擇要發佈的分支；或是對 repo push 一個符合 `v*` 格式的 git tag（例如 `v1.0.1`），workflow 自動觸發並使用該 tag 指向的 commit
- tag push 觸發時，若該 tag 指向的 commit 不在 `release` 分支的歷史中，workflow 在最早期就失敗，不執行任何簽章或上傳動作；`workflow_dispatch` 手動觸發不受此限制
- Workflow 完成後，一個新的 build 出現在 App Store Connect 的 TestFlight 分頁，build number 比目前 App Store Connect 上最新的 build number 大 1，`MARKETING_VERSION` 沿用 `project.pbxproj` 當下的值（`1.0`，這次不處理自動遞增行銷版本號）
- Internal tester 群組（若使用者已在 App Store Connect 網頁設定過）會依照 App Store Connect 既有規則收到可測試的新 build 通知
- Workflow 失敗時（簽章失敗、Archive 失敗、上傳失敗）该次 run 標示為 failure，log 中保留 fastlane 的錯誤輸出，不會有「部分成功」的中間狀態被誤判為成功

**Workflow 結構（Interface）：**
- 檔案路徑：`.github/workflows/testflight.yml`
- `name: TestFlight Release`
- `on.workflow_dispatch:`（無額外 input，使用觸發時選擇的分支/commit）與 `on.push.tags: ['v*']`（push 符合 `v*` 格式的 tag 時自動觸發，使用該 tag 指向的 commit）
- `jobs.release.runs-on: macos-latest`
- 需要的 GitHub Secrets（存在這個 repo 的 Settings → Secrets and variables → Actions）：
  - `APP_STORE_CONNECT_API_KEY_ID`：API Key 的 Key ID
  - `APP_STORE_CONNECT_API_ISSUER_ID`：Issuer ID
  - `APP_STORE_CONNECT_API_KEY_CONTENT`：.p8 檔案內容（base64 或原始內容，由 Fastfile 內的 `app_store_connect_api_key` action 讀取並還原成暫存檔）
  - `MATCH_GIT_BASIC_AUTHORIZATION` 或 `MATCH_GIT_PRIVATE_KEY`：對 `ios-signing` repo 有讀取權限的憑證（GitHub PAT 或 deploy key，用於 match 的 `git_url` 私有 repo 存取）
  - `MATCH_PASSWORD`：match 用來加解密憑證的密碼（沿用 `ios-signing` repo 建立時設定的密碼，不是新密碼）
- Steps（依序）：
  1. `actions/checkout@v4`
  2. 驗證 tag 是否指向 `release` 分支歷史中的 commit（僅 `on.push.tags` 觸發時執行，`workflow_dispatch` 觸發時跳過）：`git fetch origin release` 後執行 `git merge-base --is-ancestor "$GITHUB_SHA" origin/release`，非 0 結束碼視為不符合，立刻中止 workflow 並輸出明確錯誤訊息（不進入後續任何步驟）
  3. 安裝 Ruby/Bundler（或直接用 `gem install fastlane` / `brew install fastlane`，視 runner 內建版本決定）
  4. `xcodebuild -resolvePackageDependencies`（沿用 CI workflow 的 SPM resolve 方式）
  5. 執行 `fastlane ios beta`（Fastfile 中定義的 lane），內部依序執行：
     a. `app_store_connect_api_key`：從環境變數建立 API Key 物件
     b. `match(type: "appstore", readonly: false, git_url: "https://github.com/albertkingdom/ios-signing")`：抓取/建立三個 target 各自的 App Store provisioning profile
     c. `latest_testflight_build_number` + `increment_build_number`：設定新的 build number
     d. `build_app(scheme: "MyTaiwanStock", export_method: "app-store")`：Archive 並匯出 IPA
     e. `upload_to_testflight(skip_waiting_for_build_processing: true)`：上傳到 TestFlight
- `fastlane/Fastfile`、`fastlane/Appfile`、`fastlane/Matchfile` 為新增檔案，`Matchfile` 內 `git_url` 指向 `https://github.com/albertkingdom/ios-signing`，`git_branch` **必須明確指定為 `"main"`**（不可省略，見 Risks 中的實測教訓），`type` 預設 `appstore`

**失敗模式（Failure modes）：**
- tag push 觸發，但該 tag 指向的 commit 不在 `release` 分支歷史中 → 驗證 step 失敗並中止 workflow，log 顯示明確訊息說明此 tag 不是從 `release` 分支打的，不執行任何簽章/建置/上傳動作
- API Key 相關 Secrets 缺漏或格式錯誤 → `app_store_connect_api_key` action 失敗，workflow 在最早期就中止，不會嘗試後續任何簽章或上傳動作
- match 存取 `ios-signing` repo 失敗（權限不足、`MATCH_PASSWORD` 錯誤）→ match step 失敗並中止，不會進入 build_app
- match 產生的 provisioning profile 與 `project.pbxproj` 內 `PROVISIONING_PROFILE_SPECIFIER`／bundle id 不一致 → `build_app` 簽章失敗，錯誤訊息會指出找不到對應的 profile
- `latest_testflight_build_number` 查詢失敗（例如 App Store Connect 上此 app 從未上傳過任何 build）→ 需要有 fallback：查詢失敗或回傳 0 時，直接使用 `project.pbxproj` 當下的 `CURRENT_PROJECT_VERSION` 作為起始值遞增，避免整個 lane 因為「這是第一次上傳」而失敗
- `upload_to_testflight` 失敗（例如網路問題、App Store Connect 端驗證錯誤）→ workflow 標示 failure，此時 Archive 已完成但 build 未真正出現在 TestFlight，需要人工重跑 workflow（因為 build number 已經遞增過，重跑時 `latest_testflight_build_number` 會拿到查詢時刻的最新值，不會撞號）

**驗收標準（Acceptance criteria）：**
- 在 GitHub Actions 頁面手動觸發 `TestFlight Release` workflow，觀察 run 是否成功
- 成功後至 App Store Connect 網頁的 TestFlight 分頁，確認出現一筆新的 build，build number 正確遞增
- 刻意讓一個必要 Secret（例如 `MATCH_PASSWORD`）留空或錯誤，觸發 workflow，確認在 match 階段就正確失敗，並在 log 顯示可辨識的錯誤訊息（不是卡住或誤報成功）

**範圍邊界（Scope boundaries）：**
- 範圍內：新增 `.github/workflows/testflight.yml`、`fastlane/Fastfile`、`fastlane/Appfile`、`fastlane/Matchfile`；把三個 target 的 `CODE_SIGN_STYLE` 改為 Manual 並指定 profile；設定並文件化所需的 GitHub Secrets 清單
- 範圍外：App Store 正式上架流程、tester 群組管理、release note 自動化、`ios-signing` repo 本身的初始建立（已存在，只需要新增 MyTaiwanStock 的 profile）、修改既有 `ci.yml`

## Risks / Trade-offs

- [風險] `ios-signing` repo 裡的 distribution 憑證可能不屬於 `UZ2Z639589` 這個 team，或已過期 → [緩解] 在 tasks 早期加入驗證步驟：本機執行 `fastlane match appstore --readonly` 確認能成功抓到憑證且憑證有效期未過期，若不符則需要重新產生。**已實際發生**：repo 裡原本的 distribution 憑證（`B5D9B2S5JZ`）在 Apple 後台已經失效（極可能是 `MyTaiwanStock` 過去使用 Automatic signing 時，Xcode 在背景建立/汰換憑證所致），拿掉 `--readonly` 用 App Store Connect API Key 驗證後，match 自動生成了一張新憑證（`Apple Distribution: Yu-Kai Lin (UZ2Z639589)`，效期至 2027-01-25）並成功寫回 repo，過程沒有撤銷任何舊憑證，不影響 repo 內其他 app（`MyBusMapSwiftUI`）既有的資料
- [風險] fastlane match 的 `git_branch` 若不明確指定，預設值是 `master`；如果 storage repo 的實際分支是 `main`（如 `ios-signing`），match 會誤判成「這個分支不存在」而建立一個**與 `main` 完全沒有共同歷史的孤兒分支**，導致新資料寫錯地方、無法回頭合併 → [緩解] **已實際踩到這個陷阱**（第一次執行忘記指定 `git_branch`，資料寫進了誤建的孤兒 `master` 分支，事後已刪除該分支並改用 `git_branch("main")` 重新執行、驗證 `MyBusMapSwiftUI` 既有檔案 checksum 完全不受影響）。因此 `Matchfile` 與後續所有 `match` 呼叫（本機、CI）都必須明確帶上 `git_branch("main")`，不可依賴預設值
- [風險] `ios-signing` repo 用來加解密的 `MATCH_PASSWORD` passphrase 如果使用者自己忘記，本機/CI 都無法解密既有內容，且沒有救回機制（match 是純本地端對稱加密，沒有密碼救援後門）→ [緩解] 此次已實際發生密碼一時想不起來的狀況，所幸使用者後來想起正確密碼並成功解密；若日後再次發生且真的救不回來，因為憑證本身的真實有效性是由 Apple 伺服器端決定（不是本地檔案決定），可用 API Key 搭配拿掉 `--readonly` 的方式讓 match 重新產生一組新憑證/profile 並用新密碼重新初始化 repo，缺點是舊資料（若還有其他 app 依賴）會變成無法解密的死檔案
- [風險] 使用者不確定是否已有 App Store Connect API Key → [緩解] tasks 中包含「檢查 App Store Connect 上是否已有 API Key，若無則建立一組新的 Admin 或 App Manager 權限 key」的步驟，此步驟需要使用者親自登入 App Store Connect 完成（無法由 CI/自動化代勞），完成後才能繼續設定 GitHub Secrets
- [風險] `CODE_SIGN_STYLE` 改成 Manual 會讓本機開發者的 Xcode 建置行為改變，若沒有先跑過 `fastlane match development`，本機 build 可能失敗 → [緩解] 在 tasks 中明確加入「本機驗證：改完 Manual signing 後，跑一次 `fastlane match development` 並確認 Xcode 本機仍可正常 build/run」的步驟，且在 design 與 proposal 中已標記為 **BREAKING** 提醒使用者
- [風險] GitHub-hosted runner 上的 fastlane/Ruby 版本可能跟 `match_version.txt` 記錄的 `2.231.1` 不完全一致，導致 match 憑證格式相容性問題 → [緩解] 若發生，在 workflow 中明確 pin fastlane 版本（例如透過 `Gemfile` + `bundle exec fastlane`）而非依賴 runner 預裝版本
- [風險] `upload_to_testflight` 上傳後，App Store Connect 端的 build 處理（processing）可能需要數分鐘到數十分鐘，workflow 若等待處理完成會讓 run 時間變得不可預期 → [緩解] 已在 Implementation Contract 中決定使用 `skip_waiting_for_build_processing: true`，workflow 上傳成功即視為完成，不等待處理結果，使用者需要自行到 App Store Connect 網頁確認 build 是否通過處理
