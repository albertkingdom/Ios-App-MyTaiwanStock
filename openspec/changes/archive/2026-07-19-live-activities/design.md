## Context

MyTaiwanStock is a UIKit-based Taiwan stock tracking app (iOS 15.2+) using MVVM with Combine. It already has a StockWidget extension (WidgetKit, iOS 14.7+) that displays stock prices on the Home Screen. The app polls the TWSE API every 60 seconds via a `Timer` in `StockListViewModel`. The widget fetches data independently every 15 minutes. No Live Activity or ActivityKit code exists yet.

Live Activities require iOS 16.1+ (ActivityKit framework). The app currently targets iOS 15.2, so all ActivityKit usage must be guarded with `#available(iOS 16.1, *)`. The existing StockWidget extension targets iOS 14.7 and already imports Firebase, Charts, and shares the App Group `group.a2006mike.myTaiwanStock`.

The data model for stock prices is `OneDayStockInfoDetail` (from TWSE API), containing `stockNo`, `shortName`, `current` (price), `yesterDayPrice`, `open`, `high`, `low`, and `time`.

## Goals / Non-Goals

**Goals:**

- Display a single stock's real-time price on the Lock Screen and Dynamic Island via Live Activity
- Allow users to start a Live Activity from both the stock detail screen and the stock list long-press context menu
- Auto-update the Live Activity as the app's 60-second polling fetches new prices
- Gracefully degrade on iOS < 16.1 without affecting existing functionality
- Tap on the Live Activity to open the app to the tracked stock's detail page

**Non-Goals:**

- Push-to-start from a remote server (APNs push for Live Activity activation)
- Tracking multiple stocks simultaneously (one Live Activity at a time)
- Interactive buttons on the Live Activity (beyond tap-to-open)
- Background updates when the app is not running
- watchOS companion
- Custom deep link handling for the tap-to-open (existing navigation handles it)

## Decisions

### Live Activity in StockWidget extension vs new extension

**Decision（實作已偏離，見下方修正）**: 原始決策是把 `ActivityConfiguration` 加進既有的 StockWidget extension。

**Rationale**: Apple recommends placing Live Activity UI in an existing widget extension when one exists. The StockWidget already has App Group entitlements, Firebase setup, and shared source files. A new extension would duplicate build configuration without benefit.

**Alternatives considered**: A separate `LiveActivityExtension` target. Rejected — adds unnecessary build target overhead and code duplication.

**實際實作（drift 記錄）**: 最終實作建立了獨立的 `LiveActivityExtension` target（`LiveActivity/StockLiveActivity.swift`、`LiveActivity/Info.plist`），而非放進 StockWidget extension，與本文件原始決策相反。事後看來這反而是正確方向：後續在實機測試 widget 時發現 StockWidget extension 因為編譯了 `NetworkServiceImpl` 連帶拉進 Firebase／GoogleSignIn／Core Data，在 30MB 記憶體上限下造成問題（見 tasks.md 7.7），且已將這些依賴從 StockWidget extension 移除。若 Live Activity 當初真的合併進 StockWidget extension，會讓這個依賴問題更難排查與拆分。往後任何新增到 widget/extension 的功能，都應該優先評估是否需要獨立 target，避免把不相關的框架依賴（Firebase、Core Data 等）一起帶進記憶體受限的 extension process。

### App-driven updates via Activity.update() vs APNs push updates

**Decision**: Use local `Activity.update()` triggered by the existing 60-second polling cycle.

**Rationale**: The app already fetches live prices every 60 seconds. No server infrastructure changes required. The ActivityManager observes the same `StockCellViewModel` data flow used by the UI. Push updates would require a backend that polls TWSE independently — out of scope.

**Alternatives considered**: APNs push-to-start and push-update for reliable background updates. Rejected for this iteration — requires new server infrastructure.

### Single stock tracking vs multiple simultaneous activities

**Decision**: Support one active Live Activity at a time.

**Rationale**: Simplifies lifecycle management and avoids iOS limitations on concurrent activities. Users can switch the tracked stock by starting a new activity (the old one ends). Multiple activities increase system resource usage and may be throttled by iOS.

**Alternatives considered**: Multiple concurrent activities. Rejected to keep scope manageable for initial release.

### Shared ActivityAttributes compilation vs App Group serialization

**Decision**: Add `StockActivityAttributes.swift` to both the main app and StockWidget extension target memberships. ActivityKit handles serialization natively.

**Rationale**: `ActivityAttributes` conforms to `Codable` and ActivityKit manages the data transfer. No custom App Group serialization needed. Both targets compile the same file.

**Alternatives considered**: Custom App Group UserDefaults bridge. Rejected — ActivityKit already provides the data channel.

### Separate ActivityManager singleton vs integrating into StockListViewModel

**Decision**: Create a standalone `ActivityManager` singleton that `StockListViewModel` calls into during polling updates.

**Rationale**: Separates concerns — StockListViewModel handles data fetching and binding, ActivityManager handles ActivityKit lifecycle. The manager can be called from both StockListViewModel (auto-update) and StockDetailViewController (start/stop). Easier to test and maintain.

**Alternatives considered**: Add ActivityKit code directly into StockListViewModel. Rejected — would bloat the ViewModel with framework-specific code.

### Date formatting for display

**Decision**: Display the last update time in Taiwan timezone (`Asia/Taipei`) using `HH:mm:ss` format, matching the existing `StockCellViewModel.time` format convention.

**Rationale**: The TWSE API returns Beijing time, and the existing app already displays timestamps in this format. Consistency with existing UI conventions.

## Implementation Contract

### StockActivityAttributes (shared model)

The data contract between the main app and widget extension. Declared as a public struct conforming to `ActivityAttributes`. The `ContentState` nested struct is the mutable payload updated by the app.

```
struct StockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentPrice: String
        var priceChange: String
        var priceChangePercent: String
        var yesterDayPrice: String
        var time: String
    }
    var stockNo: String
    var stockName: String
}
```

- `stockNo` and `stockName` are fixed at activity creation (static attributes)
- `ContentState` fields are updated via `Activity.update(using:)`
- All fields use formatted String values (not raw Double) to avoid locale formatting issues in the widget

### ActivityManager API surface

```
class ActivityManager {
    static let shared = ActivityManager()

    @available(iOS 16.1, *)
    func start(stockNo: String, stockName: String,
               currentPrice: String, priceChange: String,
               priceChangePercent: String, yesterDayPrice: String,
               time: String) -> Bool

    @available(iOS 16.1, *)
    func update(currentPrice: String, priceChange: String,
               priceChangePercent: String, yesterDayPrice: String,
               time: String)

    @available(iOS 16.1, *)
    func end()
}
```

- `start()` returns `false` if an activity is already active (caller should end the existing one first), or if the content contains unexpected values
- `update()` is a no-op if no activity is active
- `end()` dismisses the activity immediately without a dismissal policy
- All methods are safe to call on iOS < 16.1 (compile-time and runtime guarded)

### StockLiveActivity UI contract

The widget extension SHALL define an `ActivityConfiguration` for the `StockActivityAttributes` type. It SHALL provide views for:

| Presentation       | Content                                                                 |
|--------------------|-------------------------------------------------------------------------|
| Lock Screen        | Stock number + name, current price (large), change (with +/- prefix and color: red up/green down), yesterday price, time |
| Dynamic Island compact leading | Stock number (e.g., "2330")                                    |
| Dynamic Island compact trailing | Price change with arrow indicator                          |
| Dynamic Island minimal | Stock number + price change                                        |
| Dynamic Island expanded | Stock name, current price (large), change + %, yesterday reference price, time |

Price colors follow Taiwan convention: red for price up (positive change), green for price down (negative change), black/white for unchanged. The tap handler SHALL not specify a custom URL — the default behavior opens the main app.

### Integration with polling

`StockListViewModel.fetchStockInfo(stockNos:)` currently calls the TWSE API and publishes results via `filteredStockCellDatasCombine`. After successful fetch, the view model SHALL iterate through the results and, if any result matches the currently tracked stock number, call `ActivityManager.shared.update(...)` with the new values.

If the user switches to a different watchlist tab that does not contain the tracked stock, the activity SHALL NOT be updated (the polling fetches different stocks). This is an intentional trade-off.

### Market close detection

When the last fetch before market close (after 13:30) shows no new data or the time stamp indicates post-market, `ActivityManager.end()` SHALL be called automatically. The detection logic SHALL check if the `time` field from the API has not changed for two consecutive polling cycles (120 seconds), treating a stale timestamp during post-market hours as the close signal.

### Acceptance criteria

1. Starting a Live Activity from stock detail screen creates a visible Lock Screen and Dynamic Island widget
2. The widget displays correct stock number, name, price, change, and timestamp matching the in-app display
3. Each 60-second polling cycle updates the widget's displayed price within 2 seconds of in-app update
4. Ending the activity (manual or auto on market close) removes it from Lock Screen and Dynamic Island
5. On iOS 15.x devices, the app functions identically to before — no crashes, no feature degradation
6. Tap on the Live Activity opens the app (standard behavior)
7. Only one Live Activity is active at a time; starting a new one dismisses the old one

### Scope boundaries

**In scope**: Local app-driven Live Activity with ActivityKit, display views for Lock Screen and Dynamic Island, start/update/end lifecycle integrated with existing polling, market-close auto-dismissal.

**Out of scope**: APNs push-to-start or push-update, multiple concurrent activities, deep-link navigation from Live Activity tap to specific stock detail, watchOS, custom dynamic island animations beyond standard system transitions, background refresh to keep activity updated when app is suspended.

## Risks / Trade-offs

- [Risk] Live Activity stops updating when the app enters background (polling stops) → Mitigation: Acceptable for initial release; the last known price remains visible. Document this limitation clearly.
- [Risk] Starting a Live Activity on iOS < 16.1 would crash → Mitigation: All ActivityKit calls are guarded with `#available(iOS 16.1, *)`. UI entry points hide on older OS versions. The StockWidget extension's `ActivityConfiguration` is only compiled for iOS 16.1+.
- [Risk] Activity may be dismissed by the user from the Lock Screen without the app knowing → Mitigation: Use `Activity.activityStateUpdates` Combine publisher to observe dismissal and clear the internal reference.
- [Risk（已發生並修復）] StockWidget extension already imports Firebase which increases binary size → 原始 Mitigation 假設「Live Activity views 是輕量 SwiftUI，不增加額外依賴，既有 Firebase import 不變」。實際上這個既有的 Firebase import（連同因 `NetworkServiceImpl` 而被迫編譯進 target 的 `OnlineDBService`／`LocalDBService`／Core Data model／GoogleSignIn）在實機測試時被證實是嚴重問題來源：widget extension process 記憶體上限僅 30MB，而 Firebase＋GoogleSignIn＋gRPC＋abseil＋leveldb 等依賴大幅擠壓可用記憶體。已於 tasks.md 7.7 移除這些依賴，`StockWidgetExtension.appex` 從數十 MB 降到約 836KB。
- [Trade-off] Only one stock tracked at a time → Less powerful than multi-track, but simpler and avoids iOS system resource limits.
- [新增 Risk] App Group 共享的 `stockNos` 清單若因主 App 端的資料同步邏輯有 bug（例如 Core Data 記錄的 `stockNo` 為 `nil` 卻被轉成空字串寫入），會讓 widget 與 Live Activity 兩者共用的資料源頭一起壞掉，且沒有機制能自我修復（只有特定使用者操作路徑才會重新同步）。已於 tasks.md 7.8 修復根本原因並讓 App 每次正常抓取股價時都同步一份正確資料給 widget。往後任何寫入 App Group 共享資料的路徑，都應確保「資料無效／nil」時是過濾掉而非轉成空字串，並確保有一條不依賴特定使用者操作的常態同步路徑。
- [新增 Risk（已發生並修復）] 7.8 修復同步邏輯時，把 `setupStockNameStringSet()` 的 `map`+`guard-else` 改成 `compactMap` 卻遺留了針對錯誤型別（Core Data `StockNo` class）的轉型，導致修復同一個 bug 的過程中引入了更嚴重的迴歸——切換清單時整個 widget 股票清單被清空而非只是含空字串。已於 tasks.md 7.10 修正。這類「修 A 順手改了 B 但沒驗證 B 的型別假設」的迴歸，凸顯了對 App Group 同步這種跨 target 共用、且只能在實機上肉眼驗證的路徑，每次修改都應該手動走過一次完整的使用者操作路徑（切換清單、新增、刪除），而不能只靠編譯通過。
- [新增 Trade-off] widget 的「前三支股票」原本依賴 Core Data 關聯順序或 `Set` 的隱含順序，兩者皆非穩定排序，導致清單在無關操作（新增/刪除其他股票）後可能洗牌。已於 tasks.md 7.13 在所有寫入 App Group 的路徑上統一改為依股票代號排序。往後任何呈現「清單前 N 筆」的畫面，都應該在資料源頭就確保排序穩定，而不是依賴寫入路徑恰好產生一致的順序。
