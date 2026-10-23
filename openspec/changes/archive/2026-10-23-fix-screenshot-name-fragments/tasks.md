## 1. 修正前重現

- [x] 1.1 在 MyTaiwanStockTests/TradeScreenshotParserTests.swift 驗證 Reassemble stock name fragments 與 Exclude profit loss from share count：先執行新增的三個測試及同檔既有測試，確認新測試在原始解析器出現 assertion failure，保留實際 Vision 文字框於 MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift。

## 2. 最小修正

- [x] 2.1 實作 Reassemble stock name fragments：在 MyTaiwanStock/Util/TradeScreenshotParser.swift 僅合併同列名稱欄內相鄰的中文、英文、數字與加號；以 test_split_chinese_and_latin_name_fragments_resolve_to_the_stock_code、test_numeric_name_fragment_does_not_replace_the_price 和獨立加號既有測試確認股號為 00757 且價格不被併入名稱。
- [x] 2.2 實作 Exclude profit loss from share count：在價格欄存在時限制股數欄位置，漏讀股數時保留 nil，維持缺上列交易的不完整行為；以 test_user_fang_screenshot_vision_output_does_not_take_profit_loss_as_shares、test_top_row_cut_off_is_incomplete_and_borrows_nothing 驗證。

## 3. 回歸驗證

- [x] 3.1 重跑 TradeScreenshotParserTests 全檔及 StockNameResolverTests，確認既有與新增案例通過；記錄測試平台限制與結果，review 未提交差異並處理中嚴重度以上發現。

## 手動驗證狀態

iOS 26.5 App 建置及完整單元測試已驗證通過，詳見下方補充紀錄。完整原圖的實機問題與後續修正記錄在 follow-up.md；使用者於重新安裝後確認「可以正常辨識」。實際儲存匯入的完整手動流程未另外確認，相關邏輯由單元測試覆蓋。使用者確認辨識功能後，已完成 commit 前的本機差異 review。

## 驗證紀錄（2026-10-23）

- 修正前：以 macOS XCTest 執行真實解析器、resolver、repository、bundled StockList.json 與原測試方法，35 項中 4 個案例失敗（共 7 個 assertion failure）；拆框名稱、數字名稱後綴與損益誤取股數可重現，窄價格下的寬股數維持通過。
- 修正後：TradeScreenshotParserTests 22 項及 StockNameResolverTests 13 項，合計 35 項全部通過。測試紀錄位於暫存檔 /tmp/stock-parser-red.log 與 /tmp/stock-parser-green.log。
- 本機複審：名稱合併受相鄰距離與名稱欄限制，數字價格保留在價格欄；股數欄以價格／淨額間距判別，維持截斷列行為。無尚未處理的中嚴重度以上發現；review 工作文件依 CLAUDE.md 在全部項目完成後移除。
- 未執行完整 iOS App build、iOS XCTest 或裝置操作驗證；未 commit。

## iOS 26.5 補充驗證（2026-10-23）

- 環境：Xcode 26.5（17F42）、iOS 26.5（23F77）、iPhone 17 模擬器（C9642110-4EC5-4F00-BE1D-6122A1467ECA）。
- 完整 App 建置及 MyTaiwanStock scheme 的 iOS XCTest 通過：191 項測試、0 失敗。包含 TradeScreenshotParserTests 22 項、StockNameResolverTests 13 項、TradeImportViewModelTests 28 項及 TradeTextRecognizerTests 3 項。
- 使用專案 CI 相同簽署參數：CODE_SIGN_IDENTITY=-、CODE_SIGNING_REQUIRED=NO、CODE_SIGNING_ALLOWED=YES。首輪停用簽署導致 App Group entitlement 未生效，測試 App 啟動中止，未執行測試；改用 CI 參數後完整重跑成功，未修改 App 程式碼。
- 成功結果：/tmp/stock-ios26-5-validation-20261023-run2.xcresult；執行記錄：/tmp/stock-ios26-5-validation-run2.log。
- 本次未進行完整選圖到匯入的手動操作，也未 commit。
