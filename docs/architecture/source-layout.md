# 原始碼目錄分工

以使用者看到的畫面與操作流程作為 UI 程式的分組邊界。同一畫面的 Controller、ViewModel、專用 View、Cell、XIB 與流程協調器放在一起；每個畫面下再依職責分為 ViewController、ViewModel、View；流程專用的協調器放 Coordinator，服務放 Services，資料型別放 Model。只建立實際有檔案的分類。

## 畫面與流程

| 目錄（位於 MyTaiwanStock/Screens） | 使用者畫面與涵蓋範圍 |
| --- | --- |
| StockList | 股票列表、新增／編輯清單、新增追蹤股票 |
| StockDetail | 股票詳情、行情圖表畫面、歷史交易紀錄列 |
| TradeEntry | 手動新增買賣紀錄、投資備註 |
| TradeImport | 截圖匯入、確認預覽、逐筆編輯與該流程專用的辨識／解析支援 |
| Dividend | 新增股利與股利明細 |
| Statistics | 統計畫面與專用紀錄列 |
| News | 新聞列表、新聞網頁閱讀 |
| Chat | 聊天畫面及群組未讀狀態 |
| Account | 帳號、登入與本機資料匯入 |
| Settings | 設定畫面與手續費固定金額編輯 |
| Onboarding | 初次使用導覽 |

`MyTaiwanStockTests/Screens/` 對應上述畫面與流程，現有相關測試依畫面歸位。沒有測試的畫面不建立空測試資料夾。

## 畫面內的職責分層

以股票列表為例：

```text
Screens/StockList/
├── ViewController/  列表、新增清單、新增股票的 Controller
├── ViewModel/       列表、Cell、新增清單與股票的 ViewModel
├── View/            股票列與新增股票列
└── Coordinator/     列表畫面的導覽協調
```

其餘畫面採相同分法。測試維持 `MyTaiwanStockTests/Screens/<畫面>/` 分組，檔名直接對應受測類別。

## 跨畫面與 App 層

- `App/`：AppDelegate、SceneDelegate、AppCoordinator、DependencyContainer、CustomTabBarViewController，負責啟動、組裝與主導覽。
- `SharedUI/`：跨畫面的浮動按鈕、字型與 UIViewController 顯示提示擴充；對應測試放 `MyTaiwanStockTests/SharedUI/`。
- `TradeCost/Model/`：共用費用設定與既有費用型別；`TradeCost/Services/`：新增、匯入與詳情共同使用的費稅與成本計算。
- `ShareImport/`：分享擴充功能與主 App 間的待匯入協調和共用資料。
- 畫面專用 Model 放在 `Screens/<畫面>/Model/`：新聞 API 型別、聊天訊息、統計數值、收藏清單、歷史行情與交易型別跟隨各自畫面。
- `Shared/Model/`：跨流程共用的即時行情、股票名錄、交易上傳型別，以及 Core Data 模型。Core Data 的版本群組、兩版模型及目前版本設定整包保留。
- `Repository/`、`Util/`：維持既有資料存取與基礎工具分工，本次未拆解這些模組。
- `Base.lproj/`、語系目錄、Assets、Resources：維持 Xcode 既有資源位置；Main.storyboard 暫不拆分。

## 維護原則

- 新畫面的程式放到對應 `Screens/` 目錄，不重建全域 `View Controller` 或 `View Model` 大目錄。
- 專用元件與支援邏輯跟著所屬畫面／流程；確認有跨畫面用途後，再提取至 SharedUI 或共用領域模組。
- 實體路徑與 Xcode group 必須一致；搬檔保留既有 file reference、target membership 與 resource membership。
- 檔名與類別名稱本次不變，既有 storyboard identifier、outlet 及 nib 名稱維持原值。
- 早期規格、已完成任務與歷史 handoff 可能引用舊路徑，請依類別名稱在對應畫面目錄定位。後續新增／修改的工作紀錄使用目前路徑。
