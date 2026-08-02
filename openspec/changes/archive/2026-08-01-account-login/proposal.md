## Why

帳號登入頁面（AccountViewController）目前沒有任何 spec 文件記錄其行為，屬於 Spectra 導入前就存在的既有功能。為了讓後續變更（例如修正已知的錯誤處理問題、補上 Firebase Auth 狀態監聽等）有一份可比對的基準（baseline），需要先將現況的登入/登出流程完整文件化，本次變更純粹是「記錄現況」，不修改任何程式碼。

## What Changes

- 新增 `account-login` capability spec，記錄目前的帳號頁面行為：
  - Google Sign-In 登入流程
  - Sign in with Apple 登入流程（含 nonce 產生與驗證）
  - Firebase Auth session 的建立、持久化（交由 SDK 管理）與登出
  - 登入/登出後 UI 狀態（`updateUI()`）的呈現規則
  - 其他功能（Firestore 資料存取、AddListViewModel）如何依賴 `Auth.auth().currentUser?.email` 判斷登入身份
  - 目前已知但尚未修正的行為限制（例如：錯誤僅印在 console、無 Firebase Auth 狀態監聽、登出未同步登出 Google SDK），以 SHALL NOT / 待改善的形式如實記錄現況，不在本次變更中修正
- 不修改 `MyTaiwanStock/View Controller/AccountViewController.swift` 或任何其他程式碼

## Non-Goals

- 不修正 AccountViewController 現有的錯誤處理、force-unwrap 或狀態同步問題（這些留待後續獨立的 bug fix 變更處理）
- 不新增 email/password 登入、忘記密碼、或其他登入方式
- 不涉及 `ChatViewModel` 的匿名登入流程細節（僅在 spec 中提及其與帳號登入是各自獨立的身份，不展開規格化）
- 不修改 Firestore 安全規則或後端設定

## Capabilities

### New Capabilities

- `account-login`: 帳號登入頁面（Google Sign-In、Sign in with Apple、Firebase Auth session、登出）的現行行為規格

### Modified Capabilities

(none)

## Impact

- Affected specs: account-login（新增）
- Affected code:
  - New: openspec/specs/account-login/spec.md
  - Modified: (none)
  - Removed: (none)
