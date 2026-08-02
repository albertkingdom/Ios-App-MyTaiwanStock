## 1. 驗證現況規格與程式碼一致

- [x] 1.1 比對 `MyTaiwanStock/View Controller/AccountViewController.swift` 中的 `googleSignIn()`／`firebaseSignIn(credential:)` 實作，確認 spec 的「Google Sign-In authentication」需求與情境如實反映現行程式碼行為（人工 code review 逐行比對）
- [x] 1.2 比對 `startSignInWithAppleFlow()` 與 `ASAuthorizationControllerDelegate` 實作，確認 spec 的「Sign in with Apple authentication」需求（含 nonce 產生、fatalError 情境）與現行程式碼一致（人工 code review）
- [x] 1.3 確認專案未自行在 `UserDefaults`／Keychain 中儲存憑證或 token，驗證 spec 的「Firebase session persistence」需求成立（於 `MyTaiwanStock/Util` 與 `AccountViewController.swift` 中搜尋是否有額外的 token 儲存邏輯，確認搜尋結果為空）
- [x] 1.4 比對 `updateUI()` 的呼叫時機與內容（`viewDidLoad`、登入/登出完成後），確認 spec 的「Account screen UI reflects authentication state」需求與情境（含未註冊 `addStateDidChangeListener` 的限制）與現行程式碼一致
- [x] 1.5 比對 `signOut()` 實作，確認 spec 的「Sign out clears the Firebase session only」需求（含未呼叫 `GIDSignIn.sharedInstance.signOut()`、錯誤僅印出的行為）與現行程式碼一致
- [x] 1.6 比對 `OnlineDBService` 與 `AddListViewModel` 中對 `Auth.auth().currentUser?.email` 的使用，確認 spec 的「Downstream features scope data by the signed-in user's email」需求與情境（含未登入時靜默 no-op）與現行程式碼一致
- [x] 1.7 比對 `ChatViewModel.signIn()` 的匿名登入實作，確認 spec 的「Anonymous chat authentication is independent of the Account screen」需求與現行程式碼一致

## 2. 歸檔前檢查

- [x] 2.1 執行 `spectra analyze account-login`，確認無 Critical 等級發現，作為本次 baseline spec 可歸檔的驗證依據
