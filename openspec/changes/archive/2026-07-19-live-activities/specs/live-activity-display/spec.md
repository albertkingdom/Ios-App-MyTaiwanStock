## ADDED Requirements

### Requirement: Lock Screen display of real-time stock price

The system SHALL display a Live Activity on the Lock Screen showing the tracked stock's current price, price change, price change percentage, yesterday's reference price, stock number, stock name, and last update timestamp.

The price change and percentage SHALL use red color (`#FF3B30` or system equivalent) for positive change (price increased) and green color (`#34C759` or system equivalent) for negative change (price decreased), following Taiwan stock market convention. The system SHALL display black or system label color when the price is unchanged.

The timestamp SHALL be formatted in `HH:mm:ss` in the `Asia/Taipei` timezone.

#### Scenario: Positive price change displayed on Lock Screen

- **WHEN** the tracked stock's current price is higher than its yesterday reference price
- **THEN** the price change and percentage SHALL appear in red with a "+" prefix

##### Example: TSMC stock up

- **GIVEN** stockNo="2330", stockName="台積電", currentPrice="1060.00", priceChange="+10.00", priceChangePercent="+0.95%", yesterDayPrice="1050.00", time="09:05:23"
- **WHEN** the Live Activity renders on Lock Screen
- **THEN** the display SHALL show "1060.00" as the large current price, "+10.00" and "+0.95%" in red, "1050.00" as yesterday reference, "2330 台積電" as the stock identifier, and "09:05:23" as the update time

#### Scenario: Negative price change displayed on Lock Screen

- **WHEN** the tracked stock's current price is lower than its yesterday reference price
- **THEN** the price change and percentage SHALL appear in green with a "-" prefix

##### Example: TSMC stock down

- **GIVEN** stockNo="2330", stockName="台積電", currentPrice="1040.00", priceChange="-10.00", priceChangePercent="-0.95%", yesterDayPrice="1050.00", time="09:05:23"
- **WHEN** the Live Activity renders on Lock Screen
- **THEN** the display SHALL show "1040.00" as the large current price, "-10.00" and "-0.95%" in green

#### Scenario: Unchanged price displayed on Lock Screen

- **WHEN** the tracked stock's current price equals its yesterday reference price
- **THEN** the price change SHALL display "0.00" in the system label color, and the percentage SHALL display "0.00%" in the system label color

### Requirement: Dynamic Island compact display

The system SHALL display the tracked stock in the Dynamic Island compact leading and trailing positions when the Live Activity is active.

The compact leading position SHALL display the stock number.

The compact trailing position SHALL display the price change amount with a "+" or "-" prefix, colored according to the Taiwan stock market convention (red up, green down).

#### Scenario: Compact leading shows stock number

- **WHEN** the Live Activity is active and the user is not in the app
- **THEN** the Dynamic Island compact leading position SHALL display the stock number (e.g., "2330")

#### Scenario: Compact trailing shows price change

- **WHEN** the Live Activity is active and the stock has a positive change of "+15.00"
- **THEN** the Dynamic Island compact trailing position SHALL display "+15.00" in red

### Requirement: Dynamic Island minimal display

The system SHALL display a minimal Dynamic Island presentation when multiple Live Activities are active and the system collapses the island.

The minimal view SHALL display the stock number and the price change amount with color coding matching the compact trailing behavior.

#### Scenario: Minimal Dynamic Island

- **WHEN** multiple Live Activities are active and the system shows the minimal presentation for this activity
- **THEN** the minimal view SHALL display the stock number and price change with color coding

### Requirement: Dynamic Island expanded display

The system SHALL display an expanded Dynamic Island view with detailed stock information including the stock name, current price (large text), price change, price change percentage, yesterday's reference price, and last update timestamp.

#### Scenario: Expanded Dynamic Island with full details

- **WHEN** the user long-presses the Dynamic Island for the stock Live Activity
- **THEN** the system SHALL show the stock name, current price in large text, price change and percentage with color coding, yesterday's reference price, and update timestamp

### Requirement: Tap Live Activity opens the app

The system SHALL open the main app when the user taps on the stock Live Activity on the Lock Screen or Dynamic Island.

#### Scenario: Tap on Lock Screen Live Activity

- **WHEN** the user taps the stock Live Activity on the Lock Screen
- **THEN** the system SHALL launch the main MyTaiwanStock app
