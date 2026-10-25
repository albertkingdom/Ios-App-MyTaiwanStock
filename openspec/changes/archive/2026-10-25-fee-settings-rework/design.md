## Context

現況（2026-10-24 查程式與討論結論）：

- `FeeSettings`（`MyTaiwanStock/TradeCost/Model/FeeSettings.swift`）有兩種模式：`.discount(Decimal)` 與 `.fixedAmount(Int)`，模式與固定金額存在 UserDefaults 的 feeMode 與 userDefinedFeeInDollars，折數存在 feeDiscount。`FeeCalculator` 在折數模式用寫死的常數整股最低 20、零股最低 1，固定金額模式直接取代公式。
- 設定頁（`SettingViewController`，storyboard 的 static table）的手續費區塊有一個分段切換器（做在 section header 裡）、一列「自訂手續費」（點下去 push 編輯頁 `EditFeeViewController`）、一列「手續費折數」（行內文字欄位），不在使用中的模式那一列會變淡。為了 Duo 這類寬螢幕上折數欄被鍵盤蓋住，又加了依鍵盤高度調整 inset 的補丁。
- 新增紀錄頁（`AddHistoryViewModel`）與截圖匯入預覽（`TradeImportViewModel`）都是用 `FeeSettings.current()` 取得設定再呼叫 `FeeCalculator.calculate`，不直接碰模式。
- 討論結論：台股券商的差異在最低手續費（元大等券商的盤中零股是「最低 1 元」，整股不足 20 元以 20 元計），固定金額只有定期定額方案才真的存在，App 沒有區分下單方式。使用者自己的券商是元大。

## Goals / Non-Goals

**Goals:**

- 手續費模型只有一種：折數加整股最低加零股最低，三個值都由使用者在設定裡決定，預設值與現行行為相同。
- 設定頁只有一列顯示目前結果，詳細設定在專用頁，不再有兩種模式並列、切換、行內輸入或鍵盤遮擋補丁。
- 升級後沒用過固定金額的人，算出來的手續費與現在完全一樣。

**Non-Goals:**

- 不做券商預設清單、不區分盤中盤後定期定額等下單方式、不讓使用者改整股與零股的 1000 股分界。
- 不改稅、Core Data 模型、Firestore 欄位、iCloud 備份、新增紀錄頁與匯入預覽的畫面。
- 不遷移也不刪除舊的 feeMode 與 userDefinedFeeInDollars。

## Decisions

### FeeSettings 改為三個值的結構，不再有模式列舉

`FeeSettings` 改成 `discount: Decimal`、`wholeLotMinimumFee: Int`、`oddLotMinimumFee: Int` 三個屬性，初始化函式 `init(discount:wholeLotMinimumFee:oddLotMinimumFee:)` 三個參數都有預設值（10、20、1）。移除 `Mode` 列舉：留一個只有 `.discount` 一個 case 的列舉只是多一層包裝。所有測試與呼叫端的 `FeeSettings(mode: .discount(X))` 機械式改成 `FeeSettings(discount: X)`；`FeeSettings.current()` 與 `FeeCalculator.calculate(... settings:)` 的簽名不變，所以新增紀錄頁與匯入預覽的程式碼不用改。替代方案：保留單一 case 的 `Mode` 讓舊寫法繼續能編譯（拒絕：多餘的型別，換來的只是少改幾行測試）。

### 最低手續費的語意與儲存

- 兩個最低手續費是 0 到 2147483647 的整數（與紀錄的手續費欄位同範圍，沿用 `ValidInputService.validFeeOrTaxInput` 的驗證），0 代表沒有最低門檻。讀取時用 `object(forKey:) as? Int`，不用 `integer(forKey:)`（沒有值時它會回 0，等於沒有最低門檻，會讓所有既有使用者的結果改變）；字串或帶小數的值視為沒有儲存，用預設值。預設值放在 `FeeSettings.defaultWholeLotMinimumFee`（20）與 `defaultOddLotMinimumFee`（1），取代 `FeeCalculator` 裡寫死的常數。
- 存在 UserDefaults 的新鍵 feeMinimumWholeLot 與 feeMinimumOddLot（整數）。讀取時沒有值或不在範圍內就用預設值。1000 股的分界仍是 `FeeCalculator.wholeLotShares`，1000 股以上但不是 1000 的倍數仍一律套用整股最低（簡化，與現在相同）。
- `FeeCalculator` 的折數公式不變，只把「取最低」改成讀設定；移除固定金額分支。

### 過渡期的 FeeSettings

為了讓每個任務完成後專案都能編譯，先擴充再移除：1.x 讓 `FeeSettings` 同時有 `mode` 與新的 `discount`、兩個最低手續費；`discount` 一律讀儲存的折數，與 `mode` 無關。`parse`、`save`、`summaryText` 與專用頁只使用 `discount` 與兩個最低手續費，不讀也不寫 `mode`；`FeeCalculator` 仍依 `mode` 計算，直到 3.1 才移除固定金額。這個狀態只存在於同一個 PR 內的中間提交，不會發版；唯一的差異是 TestFlight 上選過固定金額的測試機在中間提交上仍按固定金額計算。

### 設定頁一列加專用頁

- 設定頁的手續費區塊（storyboard 的 static table，第二個 section）只留一列：標題「手續費」、右側是摘要文字、帶 disclosure 箭頭、可點選。摘要由 `FeeSettings.summaryText` 產生：折數為 10 時是「無折扣・最低 20 / 1 元」，否則是「2.8 折・最低 20 / 1 元」。摘要在 `viewWillAppear` 重新讀取，所以從專用頁返回就會更新。section 標題改用一般的 titleForHeader 的「手續費」，不再用放切換器的自訂 header。
- 專用頁 `FeeSettingsViewController`（`init(userDefaults:)`，設定頁 push 時傳入自己的 `userDefaults`）用程式建立（`UITableViewController`，insetGrouped），不新增 storyboard scene：三列各有標題與靠右的文字欄位（折數用小數鍵盤，兩個最低手續費用數字鍵盤），欄位單位以右側文字標示，頁尾說明「折數 10 代表無折扣；最低手續費是算出來的手續費不足時改收的金額，整股指 1000 股以上，0 代表沒有最低收費」。導覽列右上角「儲存」。欄位預設顯示目前儲存的值（折數以純數字顯示，例如 2.8 或 10）。小數鍵盤與數字鍵盤沒有 return 鍵，三個欄位都用既有的 `toolBar()` 當 inputAccessoryView，提供 Done 收鍵盤；不按儲存就離開（返回鍵或滑動）時輸入捨棄，這是接受的行為；小數點為逗號的語系，小數鍵盤會輸入逗號而被折數驗證拒絕，這是既有的限制，台灣語系不受影響，不在這次處理。錯誤透過可注入的 `showError: (String) -> Void` 顯示（預設用 UIAlertController），測試因此不需要把頁面放進 window。
- 專用頁的欄位位在頁面上方，不會像設定頁那樣被鍵盤蓋住，所以不需要鍵盤補丁；`SettingViewController` 中為此加的 inset 調整、keyboard 通知與 `heightForRowAt` 隱藏列的程式一併移除。
- 修改 storyboard 的方式：把原本「自訂手續費」那列改成摘要列（標題文字改為「手續費」、右側值 label 的 outlet 改名為 `feeSummaryLabel`、selectionStyle 改為 default），刪除「手續費折數」那一列與它的文字欄位 outlet、`EditFeeViewController` 的 scene（storyboardIdentifier editFeeVC）及相關連線。這些用腳本修改並以 xmllint 檢查，再以載入設定頁的測試與 Xcode 建置確認。
- 在地化覆寫：`Main.storyboard` 在 build 內有 `zh-Hant.lproj/Main.strings`（開發語系），用 object ID 覆寫文字，「自訂手續費」那個標題的覆寫是 `mPW-VC-YWK.text`，只改 Base storyboard 的話繁中裝置仍會顯示舊標題；所以同步修改 zh-Hant 的 Main.strings（改成「手續費」並刪除已不存在物件的鍵 `ss2-gw-9Vk`、`DgW-h3-Tq7`、`JkS-Y3-3X6`），`en.lproj/Main.strings` 不在 build 內但內容相同，一併修改以保持一致。
- 摘要列的版面：原本 stack 是 fillEqually，值 label 只有一半寬，「2.8 折・最低 20 / 1 元」在 390pt 寬的 iPhone 上放不下；改為 fill，標題 label 的 compression resistance 較高，值 label 靠右、可換行，兩個 label 用 preferred 字型並開啟 adjustsFontForContentSizeCategory。摘要的數字照原樣顯示（最低為 0 就顯示 0，數字很大時由換行承接）。
- 摘要在 `viewWillAppear` 重新讀取（原本的 `initView` 在 `viewDidAppear` 呼叫，改為只刷新摘要並移到 `viewWillAppear`），所以從專用頁返回時更新；`FeeSettings.currentDiscount`、`saveDiscount` 與設定頁的 `discountText` 由 `discount`、`save` 與 `summaryText` 取代並移除。

### 儲存是三個值一起驗證，全有或全無

專用頁按儲存時，用 `FeeSettings.parse(discountText:wholeLotMinimumText:oddLotMinimumText:)` 一次驗證三個欄位：折數沿用現有的 `parseDiscount` 規則（0.1 到 10、最多兩位小數），最低手續費為 0 到 2147483647 的整數。多個值同時不合法時依折數、整股最低、零股最低的順序報第一個。任何一個不合法就丟出 `FeeSettingsError`（`invalidDiscount`、`invalidWholeLotMinimumFee`、`invalidOddLotMinimumFee`，錯誤訊息指出是哪一個），畫面顯示提示、三個值都不存、頁面維持開啟並保留使用者輸入的文字。成功時才呼叫 `FeeSettings.save`，一次寫入三個鍵，然後返回設定頁。替代方案：每個欄位離開時各自存（拒絕：折數合法、最低手續費不合法時會留下半份設定，使用者不知道哪些有生效）。

### 升級行為

不遷移。新版本完全不讀 feeMode 與 userDefinedFeeInDollars，也不寫入或刪除它們（避免回退版本時遺失）。UserDefaults 的舊鍵常數 `feeModeKey` 與 `userDefinedFeeInDollarsKey` 從程式移除（只在註解中記載兩個舊鍵名），舊的折數位置鍵 userDefinedFeeDiscount 的讀取規則保留（折數的來源不變）。曾在 TestFlight 選過固定金額的使用者會改用折數公式，這是已知且接受的影響（尚未對外發行）。

## Implementation Contract

**Behavior:**

- 設定頁手續費區塊只有一列，顯示摘要；點進去是專用頁，可修改折數、整股最低與零股最低，儲存後返回，摘要更新。
- 新增紀錄頁與匯入預覽的手續費依折數與兩個最低手續費計算；預設值下的結果與改版前完全相同；零股最低改成 5 時，5 股 @112.55、6 折的手續費由 1 變 5。
- 固定金額在畫面、設定與計算中都不存在。

**Interface / data shape:**

- `FeeSettings`（最終形態；過渡期見上面的決定）：`discount`、`wholeLotMinimumFee`、`oddLotMinimumFee`；`static let noDiscount`、`defaultWholeLotMinimumFee`、`defaultOddLotMinimumFee`；`static func current(userDefaults:) -> FeeSettings` 只讀不寫；`static func save(_ settings: FeeSettings, userDefaults:)` 一次寫三個鍵；`static func parse(discountText:wholeLotMinimumText:oddLotMinimumText:) throws -> FeeSettings`；`var summaryText: String`。
- `FeeSettingsError`：`invalidDiscount`、`invalidWholeLotMinimumFee`、`invalidOddLotMinimumFee`，各自帶指出欄位的錯誤訊息。
- UserDefaults 鍵：feeDiscount（Double，沿用）、feeMinimumWholeLot（Int）、feeMinimumOddLot（Int）。
- `FeeSettingsViewController(userDefaults:)`：程式建立，三個欄位（附 Done 工具列），儲存鈕驗證後寫入並返回；`showError: (String) -> Void` 可注入，預設顯示 UIAlertController。
- 移除：`FeeSettings.Mode`、`usesFixedAmount`、`currentFixedAmount`、`saveMode`、`saveFixedAmount`、`ValidInputService.validUserDefinedFee`、`ValidationError.invalidUserDefinedFee`、`EditFeeViewController`、設定頁的 `feeModeControl`、`feeDiscountTextfield`、`userDefinedFeeLabel`。

**Failure modes:**

- 任何一個欄位不合法：提示指出是哪一個，三個值都不存，頁面不關閉，輸入保留。
- UserDefaults 中的最低手續費不是整數或超出範圍：該值用預設值，不閃退。
- 舊版存的 feeMode 與固定金額：忽略，不讀、不改、不刪。

**Acceptance criteria:**

- `FeeCalculatorTests`：規格範例表的 13 列全部通過（含零股最低 5、整股最低 30、整股最低 0），固定金額相關測試已移除。
- `FeeSettingsTests`：什麼都沒存時折數 10、最低 20 與 1；存過的值讀得回來；超出範圍或不是整數的最低手續費用預設值；舊折數位置鍵換算為位置加一且不寫入新鍵；舊的 feeMode 與固定金額鍵存在時結果仍是折數公式、且鍵沒有被改動；`parse` 對每個不合法輸入（折數 0、11、2.855、abc、空白；最低手續費 -1、20.5、abc、空白、2147483648）丟出對應的錯誤；`summaryText` 為「無折扣・最低 20 / 1 元」與「2.8 折・最低 20 / 1 元」。
- `FeeSettingsViewControllerTests`（頁面放進 `UINavigationController`、注入收集訊息的 `showError`）：顯示目前儲存的值；輸入合法值按儲存後三個值都存入且導覽堆疊少一層；折數合法但整股或零股最低手續費不合法時，什麼都沒存、頁面仍在、輸入保留、訊息指出是整股或零股最低手續費。
- `SettingViewControllerTests`：手續費區塊只有一列，摘要文字正確；從專用頁返回後摘要更新；沒有分段切換器；iCloud 備份區塊的既有測試不受影響。
- 完整單元測試通過；在 MyTaiwanStock/、MyTaiwanStockTests/（舊鍵測試除外）、Main.storyboard、zh-Hant 與 en 的 Main.strings、project.pbxproj 搜尋 fixedAmount、feeModeControl、EditFeeViewController、validUserDefinedFee、editFeeVC、FeeSettings(mode 沒有殘留（舊鍵名只留在註解）；繁中與英文語系的設定頁手續費標題都是「手續費」。
- 手動：在 iPhone 與 iPhone Duo（Xcode 27.1 建置）確認設定頁一列、專用頁三欄位、鍵盤不遮住欄位、最大 Dynamic Type 字級下摘要不被截斷；改零股最低後新增紀錄頁的手續費跟著變；用升級前選過固定金額的資料升級後設定頁顯示折數摘要。

**Scope boundaries:**

- 在範圍內：`FeeSettings`、`FeeCalculator`、`ValidInputService` 的固定手續費驗證、UserDefaults 鍵、設定頁與其 storyboard、新的專用頁、移除 `EditFeeViewController`、對應測試與規格、`docs/architecture/source-layout.md` 的設定頁說明。
- 不在範圍內：新增紀錄頁與匯入預覽的畫面與邏輯（除了測試中 `FeeSettings` 的建構方式）、稅、Core Data、Firestore、iCloud 備份、券商預設、下單方式、1000 股分界的設定。

## Risks / Trade-offs

- [使用者把最低手續費填 0 又忘記] → 專用頁頁尾說明 0 代表沒有最低收費；手續費算出 0 是合法的紀錄值。
- [舊 TestFlight 使用者選過固定金額，升級後回到折數公式] → 尚未對外發行，只影響自己與測試者；發版說明提一句。
- [手改 storyboard 出錯] → 用腳本修改、xmllint 檢查，並有載入設定頁的測試與 Xcode 建置；Duo 與 iPhone 手動確認。
- [摘要文字太長，在窄螢幕或最大字級被截斷] → 摘要 label 允許換行；最大 Dynamic Type 與 Duo 手動確認。
- [1000 股分界與券商的拆單規則不同（例如 1500 股實際是整股加零股兩筆）] → 維持簡化並在規格寫明，不在這次處理。

## Migration Plan

資料不需要遷移：新鍵沒有值時用預設值，舊鍵不動。回退方式是還原這個變更的 commit；因為舊鍵沒有被刪除，回退後原本的設定仍在。
