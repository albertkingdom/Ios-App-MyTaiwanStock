## MODIFIED Requirements

### Requirement: Mandatory preview with per-trade confirmation

The system SHALL present every recognized trade in a preview screen before anything is written, and SHALL NOT provide a way to import without the preview. The user SHALL be able to select or deselect each trade and to edit its stock number, price, shares, date, direction, fee, and for a sell the tax. A trade SHALL be shown as incomplete and SHALL NOT be selectable when its stock number, price, shares or date is missing, when its shares are not an integer from 1 to 32767, when its price is not greater than 0, or when its fee or tax is negative, is not a whole number, or is above 2147483647. When a trade matches more than one status, the system SHALL show the first applicable status in this order: unsupported, incomplete, duplicate, importable. After the user edits a trade, the system SHALL recompute its status, SHALL select the trade when it becomes importable, and SHALL deselect it when it becomes duplicate or incomplete. The import action SHALL be disabled while no trade is selected.

#### Scenario: Incomplete trade cannot be selected

- **WHEN** a recognized trade has no year fragment and therefore no date
- **THEN** the preview SHALL mark it as incomplete and not selectable
- **AND** after the user enters a valid date the trade SHALL become selectable

#### Scenario: Shares out of range

- **WHEN** a trade has 33000 shares
- **THEN** the preview SHALL mark it as incomplete and not selectable

##### Example: share count validation

| Shares | Status |
| --- | --- |
| 0 | incomplete |
| 1 | valid |
| 32767 | valid |
| 32768 | incomplete |
| 33000 | incomplete |

#### Scenario: Invalid fee

- **WHEN** the user enters a fee of -5 in the trade editor
- **THEN** the preview SHALL mark the trade as incomplete and not selectable
- **AND** after the user changes the fee to 5, or deletes it and leaves the field so that the estimate is shown again, the trade SHALL become selectable

#### Scenario: Nothing selected

- **WHEN** the user has deselected every trade
- **THEN** the import action SHALL be disabled

### Requirement: Write through the existing record flow

When the user confirms the import, the system SHALL first validate every selected trade, and SHALL write nothing when any selected trade is invalid. After validation passes, the system SHALL write each selected trade on the main actor through the same save-new-record flow used by manual entry, so that the local store and Firestore receive the record as they do for manual entry. The system SHALL write the stock number, direction, price, shares, date, fee and tax, with an empty reason, where the fee and the tax are the values shown for that trade in the preview, estimated or edited, and the tax of a buy is written as 0. Shares SHALL be stored in the unit of shares without conversion. The stored date of an imported trade SHALL be 12:00:00.000 on the trade's calendar date in the Asia/Taipei time zone; when that millisecond timestamp is already used by an existing local record or by an earlier trade in the same batch, the system SHALL add one millisecond at a time until the timestamp is unused. The system SHALL report the number of records submitted for writing.

#### Scenario: Confirmed import writes selected trades only

- **WHEN** the preview contains three trades, two selected and one deselected, and the user confirms
- **THEN** the system SHALL call the save-new-record flow exactly twice
- **AND** the system SHALL report that two records were submitted

##### Example: odd-lot trade stored in shares

- **GIVEN** the parsed trade 元大台灣50 買進 5 股 價格 112.55 日期 2026-09-30 and a fee discount of 10
- **WHEN** the user confirms the import
- **THEN** the stored record has stockNo 0050, status 0 (buy), amount 5, price 112.55, fee 1, tax 0 and date 2026-09-30 12:00:00.000 Asia/Taipei

#### Scenario: Same-day trades get distinct timestamps

- **WHEN** the user imports one trade for 0050 and one for 2344, both dated 2026-09-30
- **THEN** the stored dates SHALL be 2026-09-30 12:00:00.000 and 2026-09-30 12:00:00.001 in the Asia/Taipei time zone
- **AND** both dates SHALL be on the same Asia/Taipei calendar day

#### Scenario: Invalid selected trade blocks the whole import

- **WHEN** one of the selected trades has an invalid share count and the user confirms
- **THEN** the system SHALL NOT write any record
- **AND** the system SHALL show an error

#### Scenario: Estimated fee and tax are stored

- **WHEN** the preview shows an estimated fee of 6 and an estimated tax of 22 for the 瑞昱 sell row and the user confirms
- **THEN** the stored record SHALL contain a fee of 6 and a tax of 22

#### Scenario: Cleared fee returns to the estimate

- **WHEN** the user deletes the fee of a trade in the editor and leaves the field without typing
- **THEN** the editor SHALL show the estimated fee again and the confirmed import SHALL store that estimate

## ADDED Requirements

### Requirement: Estimate fee and tax in the preview

The preview SHALL show an estimated fee and an estimated tax for every trade, computed with the same calculation and the same fee settings as manual entry. The tax category used for the estimate SHALL be ETF when the stock number starts with 00 and general stock otherwise, and the tax of a buy SHALL be 0 and SHALL NOT be editable. The trade editor SHALL let the user change the fee, and for a sell the tax, to a whole-dollar number; when the user leaves such a field empty, the editor SHALL show the estimate again. When the user edits the stock number, price, shares or direction of a trade in the editor, the system SHALL estimate again the fee and the tax that the user has not changed by hand, and SHALL keep the values the user changed by hand. A trade whose price or shares are missing SHALL have no estimate until they are entered. The system SHALL NOT read the fee or the tax from the screenshot text in this capability.

#### Scenario: Sell estimate

- **WHEN** the preview contains a sell of 10 shares of 瑞昱 at 757 and the fee discount is 6
- **THEN** the preview SHALL show a fee of 6 and a tax of 22 for that trade

#### Scenario: ETF sell estimate

- **WHEN** the preview contains a sell of 1000 shares of 0050 at 100 and the fee discount is 10
- **THEN** the preview SHALL show a fee of 142 and a tax of 100 for that trade

#### Scenario: Estimate after completing a trade

- **WHEN** a trade has no price and the user enters a price of 757 for 10 shares in the editor and has not touched the fee
- **THEN** the preview SHALL show the estimated fee for that price

#### Scenario: Direction changed

- **WHEN** the user changes a buy to a sell in the editor and has not touched the tax
- **THEN** the preview SHALL show the estimated tax for the sell

#### Scenario: Edited fee is kept

- **WHEN** the user changes the fee of a trade to 3 and then changes its price in the editor
- **THEN** the preview SHALL still show a fee of 3 for that trade
- **AND** the confirmed import SHALL store a fee of 3
