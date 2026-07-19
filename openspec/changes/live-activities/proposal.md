## Why

Users of this stock tracking app need to monitor real-time stock prices without unlocking their phone or navigating into the app. During Taiwan stock market hours (9:00–13:30), price fluctuations happen every 15–25 seconds. A Live Activity on the Lock Screen and Dynamic Island enables at-a-glance price monitoring, making the app more useful for active traders and casual investors alike. No other Taiwan stock tracking app currently offers Live Activities.

## What Changes

- Add a Live Activity widget to the existing StockWidget extension, displaying real-time stock price on the Lock Screen and Dynamic Island (iOS 16.1+)
- Create a shared `StockActivityAttributes` model for the data contract between the main app and the widget extension
- Add `ActivityManager` class to the main app to manage activity lifecycle: start, update, and end
- Integrate with the existing 60-second TWSE polling loop in `StockListViewModel` to push price updates to any active Live Activity
- Add UI entry points: a "追蹤即時報價" button on the stock detail screen and a long-press context menu option on the stock list
- Guard all ActivityKit usage with `#available(iOS 16.1, *)` so the app continues to work on iOS 15.2+
- Add `NSSupportsLiveActivities: YES` to the main app's Info.plist

## Non-Goals

- Push-to-start Live Activities from a remote server (this change uses local app-driven start only)
- watchOS companion Live Activity
- Tracking multiple stocks simultaneously via Live Activities (initial release supports one stock at a time)
- Interactive buttons on the Live Activity (beyond the default tap-to-open-app behavior)
- Background push updates when the app is not running (the 60-second polling only updates when the app is in the foreground)

## Capabilities

### New Capabilities

- `live-activity-display`: SwiftUI views for Lock Screen, Dynamic Island (compact/minimal/expanded), displaying stock number, name, current price, price change, change percentage, yesterday's reference price, and last update timestamp
- `live-activity-management`: App-side lifecycle for starting a Live Activity from the stock detail screen or stock list context menu, auto-updating it during the 60-second polling cycle, and ending it on manual dismissal or market close

### Modified Capabilities

(none)

## Impact

- Affected specs: `live-activity-display`, `live-activity-management`
- Affected code:
  - New: `MyTaiwanStock/ActivityKit/StockActivityAttributes.swift`
  - New: `MyTaiwanStock/ActivityKit/ActivityManager.swift`
  - New: `LiveActivity/StockLiveActivity.swift`（獨立 `LiveActivityExtension` target，非原計畫的 StockWidget extension，見 design.md drift 記錄）
  - New: `LiveActivity/Info.plist`
  - Modified: `MyTaiwanStock/StockList/ViewModel/StockListViewModel.swift`
  - Modified: `MyTaiwanStock/StockList/ViewController/StockListViewController.swift`（長按選單啟動 Live Activity）
  - Modified: `MyTaiwanStock/View Controller/StockViewController.swift`（詳情頁按鈕啟動/結束 Live Activity）
  - Modified: `MyTaiwanStock/Info.plist`
  - Modified: `MyTaiwanStock.xcodeproj/project.pbxproj`

### 實機測試後追加的變更（見 tasks.md 第 7 組）

- Modified: `MyTaiwanStock/Repository/NetworkServiceImpl.swift`（修正 completion handler 不回呼的 bug）
- Modified: `StockWidget/StockWidget.swift`（移除 Firebase 依賴、修正 containerBackground、加上收盤價/名稱 fallback、過濾空字串 stockNos）
- New: `StockWidget/WidgetStockFetcher.swift`（取代 widget 對 `NetworkServiceImpl` 的依賴）
- Modified: `MyTaiwanStock.xcodeproj/project.pbxproj`（移除 `StockWidgetExtension` target 對 Firebase/GoogleSignIn/Core Data 的連結）
