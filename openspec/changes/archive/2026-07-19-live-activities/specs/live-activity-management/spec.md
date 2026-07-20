## ADDED Requirements

### Requirement: Start Live Activity from stock detail screen

The system SHALL provide a UI control on the stock detail screen that starts a Live Activity for the currently viewed stock.

On iOS 16.1 or later, a "追蹤即時報價" button SHALL be visible. On iOS versions earlier than 16.1, this button SHALL be hidden.

When the user taps the button, the system SHALL create a Live Activity using the current stock's data (`stockNo`, `stockName`, `currentPrice`, `priceChange`, `priceChangePercent`, `yesterDayPrice`, `time`) via the `ActivityManager`. If a Live Activity is already active for a different stock, the system SHALL end the existing activity before starting the new one.

#### Scenario: Start Live Activity from detail screen on iOS 16.1+

- **WHEN** the user is viewing a stock detail screen on iOS 16.1+ and taps "追蹤即時報價"
- **THEN** a Live Activity SHALL appear on the Lock Screen and Dynamic Island with the current stock's data

#### Scenario: Start Live Activity replaces existing activity

- **WHEN** a Live Activity for stock "2330" is active and the user starts a new activity for stock "0050"
- **THEN** the "2330" activity SHALL be dismissed and a new "0050" activity SHALL appear

#### Scenario: Button hidden on iOS < 16.1

- **WHEN** the user views a stock detail screen on iOS 15.x
- **THEN** the "追蹤即時報價" button SHALL NOT be visible

### Requirement: Start Live Activity from stock list context menu

The system SHALL provide a context menu option on the stock list to start a Live Activity for a selected stock.

On iOS 16.1 or later, a "開啟即時報價" option SHALL appear in the list cell's context menu (triggered by long press). On iOS versions earlier than 16.1, this option SHALL be hidden.

#### Scenario: Context menu shows Live Activity option on iOS 16.1+

- **WHEN** the user long-presses a stock in the watchlist on iOS 16.1+
- **THEN** the context menu SHALL include an "開啟即時報價" option
- **WHEN** the user selects it
- **THEN** a Live Activity for that stock SHALL start

### Requirement: Auto-update Live Activity during polling

The system SHALL automatically update the active Live Activity's displayed data each time the 60-second TWSE polling fetches updated price information for the tracked stock.

If the tracked stock's data has not changed since the last update, the system SHALL still send an update to keep the Live Activity timestamp current. If the tracked stock is not present in the current polling results (e.g., user switched to a different watchlist tab), the system SHALL NOT update the Live Activity.

#### Scenario: Live Activity updates on polling with new price

- **WHEN** the 60-second polling fetch returns new price data for the tracked stock
- **THEN** the Live Activity SHALL update its currentPrice, priceChange, priceChangePercent, and time within 2 seconds of the in-app UI update

#### Scenario: Live Activity does not update when tracked stock not in poll results

- **WHEN** the user switches to a different watchlist tab that does not contain the tracked stock
- **AND** the 60-second polling fetches data for that tab
- **THEN** the Live Activity SHALL retain its last-displayed values and SHALL NOT be updated

### Requirement: End Live Activity on manual dismissal

The system SHALL allow the user to end the Live Activity by tapping a dismissal control on the stock detail screen or by swiping the activity away from the Lock Screen.

When the user taps the dismissal control on the detail screen, the `ActivityManager` SHALL call `end()` which dismisses the Live Activity immediately. When the user swipes the Live Activity away from the Lock Screen, the system SHALL detect this via `Activity.activityStateUpdates` and clear the internal activity reference.

#### Scenario: End activity from detail screen

- **WHEN** the user is viewing a stock detail screen with an active Live Activity and taps the "停止追蹤" button
- **THEN** the Live Activity SHALL disappear from the Lock Screen and Dynamic Island
- **AND** the button SHALL revert to "追蹤即時報價"

#### Scenario: Activity dismissed by user from Lock Screen

- **WHEN** the user swipes the Live Activity away from the Lock Screen
- **THEN** the `ActivityManager` SHALL detect the dismissal and clear its internal reference
- **AND** the stock detail screen control SHALL revert to "追蹤即時報價"

### Requirement: Auto-end activity on Taiwan market close

The system SHALL automatically end the Live Activity when the Taiwan stock market closes for the day. The market close SHALL be detected when the TWSE API time field stops advancing during post-market hours (after 13:30), remaining unchanged for two consecutive polling cycles (120 seconds).

#### Scenario: Auto-end on market close detection

- **WHEN** the time is 13:31 and the TWSE API returns a time field of "13:30:00" for two consecutive polling cycles
- **THEN** the system SHALL call `ActivityManager.end()` to dismiss the Live Activity

#### Scenario: No auto-end during market hours

- **WHEN** the time is 11:00 and the TWSE API returns the same time field for two consecutive polling cycles (e.g., during a trading halt)
- **THEN** the system SHALL NOT auto-end the Live Activity
