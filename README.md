# 台灣股票記帳
<img src="https://i.imgur.com/bygmNjn.png" width="150px" class="m-1 text-center"/>

## 功能
在手機端儲存追蹤股票清單，查看即時股價、近期k線圖、股市新聞、儲存買賣紀錄、計算損益，以及結合firebase的聊天室。 另外也提供桌面Widget。

## 技術

- MVVM架構
- 結合3rd party套件:
   1. Charts畫出k線圖、圓餅圖
  2. SQL本機資料庫、FireStore異機同步資料
  3. 整合Google、Apple三方登入

## 發版流程（TestFlight）

### 分支策略

```
mvvm (日常開發)  →  release (待發版)  →  打 tag v*  →  自動上傳 TestFlight
```

- 日常開發在 `mvvm` 分支，push / PR 會觸發 `ci.yml`（build + 跑 unit tests，不簽署）
- 要發版時，把 `mvvm` merge 進 `release` 分支
- 在 `release` 分支上打一個 `v*` 格式的 tag（例如 `v1.19.0`）並 push，會自動觸發 `testflight.yml`
- tag 版號應與 `MARKETING_VERSION` 一致（`v1.20.0` 對應 `1.20`）。不一致時 workflow 會顯示警告，但不會中止，App 仍以 `MARKETING_VERSION` 上傳
- `testflight.yml` 有保護機制：若 tag 指向的 commit 不在 `release` 分支歷史裡，會直接失敗中止，不會誤發版

### 自動化流程做的事（`.github/workflows/testflight.yml`）

1. 用 App Store Connect API Key 認證（不需要 Apple ID 帳密 / 2FA）
2. `fastlane match appstore` 同步簽署憑證與 provisioning profile
3. 查詢 App Store Connect 上此 App 歷史最大 build number，自動遞增（避免撞號）
4. Archive + Export
5. 上傳到 TestFlight（`skip_waiting_for_build_processing: true`，上傳成功即視為完成，不等處理結果）

上傳完成後，需自行到 App Store Connect 網頁確認 build 是否通過處理。

### 手動觸發

不想等 tag，也可以在 GitHub 網頁「Actions → TestFlight Release → Run workflow」手動觸發，會用當下選擇的分支/commit 執行（不受 `release` 分支限制）。

### 本機同步簽署（不透過 CI）

需要先建立 `fastlane/.env`（此檔案已加入 `.gitignore`，不會被 commit），內容包含：

```
MATCH_GIT_URL=git@github.com:albertkingdom/ios-signing.git
MATCH_GIT_BRANCH=main
MATCH_PASSWORD=<match 密碼>
APP_STORE_CONNECT_API_KEY_ID=<Key ID>
APP_STORE_CONNECT_API_ISSUER_ID=<Issuer ID>
APP_STORE_CONNECT_API_KEY_CONTENT=<.p8 檔案完整內容>
```

接著執行：

```bash
fastlane sync_signing type:appstore        # 只同步簽署資產
fastlane sync_signing type:appstore force:true  # 強制重新產生 provisioning profile
fastlane beta                              # 完整流程：同步簽署 + build + 上傳 TestFlight
```

### 所需 GitHub Secrets（Settings → Secrets and variables → Actions）

| Secret | 用途 |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | API Key 的 Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `.p8` 私鑰檔案內容 |
| `MATCH_GIT_PRIVATE_KEY` | 對 `ios-signing` repo 唯讀的 SSH deploy key 私鑰 |
| `MATCH_PASSWORD` | match 用來加解密 `ios-signing` repo 的密碼 |

### 簽署憑證注意事項

`ios-signing` repo 的 `main` 分支目前只存唯一一把正式的 Apple Distribution 憑證（序號 `B5D9B2S5JZ`），CI 與本機都應統一使用這一把。若本機 Keychain 出現「provisioning profile doesn't include signing certificate」或 Signing Certificate 顯示 `None`，優先檢查 Keychain 裡是否意外存在**多把名稱相同**的 `Apple Distribution` 憑證（可能是本機曾用 API Key 手動跑 match 時意外產生的孤兒憑證），而不是重新產生 profile。
