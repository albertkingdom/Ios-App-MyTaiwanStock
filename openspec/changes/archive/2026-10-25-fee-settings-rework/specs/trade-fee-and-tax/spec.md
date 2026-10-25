## ADDED Requirements

### Requirement: Choose the fee discount and minimum fees in settings

The settings screen SHALL show the fee settings as one row that states the saved fee discount and the two minimum fees, for example "2.8 折・最低 20 / 1 元", and "無折扣・最低 20 / 1 元" when the discount is 10. Selecting the row SHALL open a settings page with three fields: the fee discount, the whole-lot minimum fee and the odd-lot minimum fee. The fee discount SHALL be a number from 0.1 to 10 with at most two decimal places, where 10 means no discount. Each minimum fee SHALL be a whole number of dollars from 0 to 2147483647. When the user saves the page, the system SHALL validate the three values together; when any of them is invalid, the system SHALL show an error that names the invalid value (the first invalid one in the order discount, whole-lot minimum fee, odd-lot minimum fee), SHALL NOT save any of the three values, and SHALL keep the page open with what the user typed. When the user returns to the settings screen, the row SHALL show the values that are saved. When no discount has been saved, the discount SHALL be 10; when only the earlier discount choice, a whole-number position, was saved, the system SHALL read it as the discount equal to that position plus one, without changing what is stored. When no minimum fee has been saved, or a saved minimum fee is not a whole number from 0 to 2147483647, that minimum fee SHALL be the default: 20 for the whole-lot minimum fee and 1 for the odd-lot minimum fee. The fee mode and the fixed fee amount that an earlier version saved SHALL be ignored, and SHALL NOT be changed or deleted.

#### Scenario: Decimal discount

- **WHEN** the user enters a discount of 2.8 and saves
- **THEN** the system SHALL compute fees with a discount of 2.8

#### Scenario: Discount out of range

- **WHEN** the user enters a discount of 0 or of 11 and saves
- **THEN** the system SHALL show an error, SHALL NOT save any value and SHALL keep the page open

#### Scenario: Discount with three decimal places

- **WHEN** the user enters a discount of 2.855 and saves
- **THEN** the system SHALL show an error and SHALL NOT save any value

#### Scenario: Earlier discount choice

- **WHEN** the earlier saved choice is the sixth entry and no new discount is saved
- **THEN** the discount SHALL be 6

#### Scenario: Minimum fees are saved

- **WHEN** the user enters a whole-lot minimum fee of 20 and an odd-lot minimum fee of 5 and saves
- **THEN** the system SHALL compute fees with an odd-lot minimum of 5

#### Scenario: Saved minimum fee that is not usable

- **WHEN** the stored odd-lot minimum fee is the text "20" or the number 20.5 or -1
- **THEN** the odd-lot minimum fee SHALL be the default of 1

#### Scenario: Minimum fee that is not valid

- **WHEN** the user enters, in the whole-lot minimum fee field or in the odd-lot minimum fee field, a value of "-1", "20.5", "abc", "" or 2147483648 and saves
- **THEN** the system SHALL show an error that names that minimum fee and SHALL NOT save any value

#### Scenario: One invalid value blocks all three

- **WHEN** the user enters a valid discount of 2.8 and an invalid minimum fee and saves
- **THEN** the saved discount and both saved minimum fees SHALL stay as they were before

#### Scenario: Several invalid values

- **WHEN** the user enters a discount of 11 and a whole-lot minimum fee of "-1" and saves
- **THEN** the error SHALL name the discount

#### Scenario: Summary of the saved settings

- **WHEN** the saved discount is 2.8, the whole-lot minimum fee is 20 and the odd-lot minimum fee is 1
- **THEN** the settings row SHALL read "2.8 折・最低 20 / 1 元"

#### Scenario: Nothing saved

- **WHEN** no fee setting was ever saved
- **THEN** the settings row SHALL read "無折扣・最低 20 / 1 元"

#### Scenario: Fixed fee from an earlier version

- **WHEN** a user who saved the fixed-amount fee mode in an earlier version starts the app after the upgrade
- **THEN** the system SHALL compute fees with the discount formula
- **AND** the earlier mode and amount SHALL remain stored without being read

##### Example: earlier fixed fee is ignored

- **GIVEN** the stored fee mode is "fixedAmount", the stored fixed amount is 30, and no discount and no minimum fee were saved
- **WHEN** the user buys 1000 shares at a price of 100
- **THEN** the fee SHALL be 142, not 30

## MODIFIED Requirements

### Requirement: Calculate fee and tax with one rule set

The system SHALL compute the fee and the transaction tax of a trade with one calculation that uses decimal arithmetic, and SHALL return no result when the price is not greater than 0 or the share count is less than 1. The trade value SHALL be the price multiplied by the number of shares, without rounding. A fee discount stored as a binary floating-point number SHALL be converted to a decimal through its shortest decimal text, so that a discount of 2.8 is exactly 2.8. The fee SHALL be the trade value multiplied by 0.001425 and by the fee discount divided by 10, rounded down to a whole New Taiwan dollar, where a discount of 10 means no discount, and the fee SHALL then be raised to the minimum fee that applies: the whole-lot minimum fee when the trade has 1000 shares or more, and the odd-lot minimum fee when the trade has fewer than 1000 shares. The two minimum fees SHALL be the values the user saved in the settings, and SHALL be 20 for a whole lot and 1 for an odd lot when nothing was saved; a minimum fee of 0 means that no minimum applies to that kind of trade. The tax SHALL be 0 for a buy. For a sell, the tax SHALL be the trade value multiplied by the tax rate of the chosen category, rounded down to a whole dollar, where the categories are general stock 0.3%, same-day stock trade 0.15%, ETF 0.1% and exempt 0%. A trade of 1000 shares or more that is not a multiple of 1000 SHALL use the whole-lot minimum fee.

#### Scenario: Buy without discount

- **WHEN** the user buys 1000 shares at a price of 100 with a discount of 10
- **THEN** the fee SHALL be 142 and the tax SHALL be 0

#### Scenario: Fee below the minimum is raised

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6 and the saved whole-lot minimum fee is 20
- **THEN** the calculated fee of 17 SHALL be raised to the whole-lot minimum of 20

#### Scenario: Odd-lot minimum fee from the settings

- **WHEN** the user buys 5 shares at a price of 112.55 with a discount of 6 and the saved odd-lot minimum fee is 5
- **THEN** the calculated fee of 0 SHALL be raised to the odd-lot minimum of 5

#### Scenario: Whole-lot minimum fee from the settings

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6 and the saved whole-lot minimum fee is 30
- **THEN** the fee SHALL be 30

#### Scenario: No minimum fee

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6 and the saved whole-lot minimum fee is 0
- **THEN** the fee SHALL be the calculated 17

#### Scenario: Minimum fees are not saved

- **WHEN** no minimum fee was ever saved and the user buys 5 shares at a price of 112.55 with a discount of 6
- **THEN** the fee SHALL be the default odd-lot minimum of 1

#### Scenario: Decimal discount without a rounding error

- **WHEN** the discount is 2.8 and the user sells 1000 shares at a price of 1000
- **THEN** the fee SHALL be 399, not 398

#### Scenario: Invalid trade has no result

- **WHEN** the price is 0 or the share count is 0
- **THEN** the calculation SHALL return no fee and no tax

##### Example: fee and tax by trade

| Side | Shares | Price | Discount | Whole-lot minimum | Odd-lot minimum | Category | Fee | Tax |
| ---- | ------ | ----- | -------- | ----------------- | --------------- | -------- | --- | --- |
| Buy | 1000 | 100 | 10 | 20 | 1 | general stock | 142 | 0 |
| Sell | 1000 | 105 | 6 | 20 | 1 | general stock | 89 | 315 |
| Buy | 5 | 112.55 | 6 | 20 | 1 | general stock | 1 | 0 |
| Sell | 10 | 757 | 6 | 20 | 1 | general stock | 6 | 22 |
| Buy | 1 | 2470 | 6 | 20 | 1 | general stock | 2 | 0 |
| Buy | 1000 | 20 | 6 | 20 | 1 | general stock | 20 | 0 |
| Sell | 2000 | 22 | 6 | 20 | 1 | ETF | 37 | 44 |
| Sell | 1000 | 100 | 10 | 20 | 1 | exempt | 142 | 0 |
| Buy | 999 | 1 | 10 | 20 | 1 | general stock | 1 | 0 |
| Buy | 1500 | 1 | 10 | 20 | 1 | general stock | 20 | 0 |
| Buy | 5 | 112.55 | 6 | 20 | 5 | general stock | 5 | 0 |
| Buy | 1000 | 20 | 6 | 30 | 1 | general stock | 30 | 0 |
| Buy | 1000 | 20 | 6 | 0 | 1 | general stock | 17 | 0 |

### Requirement: Enter fee and tax when adding a record by hand

On the add-record screen the system SHALL compute the fee from the final text of the price and shares fields, using the fee discount and the minimum fees from the settings screen, every time the price or the shares change, when the side changes between buy and sell, and when the tax category changes. The fee and the tax SHALL be shown in editable fields that contain only the number; the unit SHALL be shown beside the field. For a sell, the system SHALL show the tax field and a choice of tax category with general stock as the default and SHALL compute the tax from the chosen category; for a buy the system SHALL NOT show a tax field and SHALL store a tax of 0. When the user types in the fee field or the tax field, that field SHALL keep the user's value when the price, the shares, the side or the category change afterwards. While the user is editing, an empty field SHALL stay empty so that a new number can be typed, and when the user leaves a field that is still empty the system SHALL show the computed value again and SHALL compute that field automatically again. The system SHALL store the values shown in the fields. The system SHALL reject a share count above 32767, and a fee or tax that is negative, not a whole number, or above 2147483647, SHALL show an input error for it and SHALL NOT write a record.

#### Scenario: Fee follows the final text

- **WHEN** the price field shows 100 and the user types the shares one character at a time, ending with 1000
- **THEN** the fee field SHALL show the fee computed for 1000 shares after the last character is typed

#### Scenario: Sell shows tax controls

- **WHEN** the user switches the record to a sell
- **THEN** the system SHALL show the tax field and the tax category choice and SHALL compute the tax from the price and shares

#### Scenario: Switching the side recomputes

- **WHEN** the price is 105, the shares are 1000, the side is a buy, and the user switches to a sell
- **THEN** the tax SHALL be computed for the sell

#### Scenario: Manual value is kept

- **WHEN** the user types 50 in the fee field and then changes the shares
- **THEN** the fee field SHALL still show 50

#### Scenario: Retyping after deleting the value

- **WHEN** the fee field shows 142, the user deletes all digits and types 50
- **THEN** the fee field SHALL show 50 and the stored fee SHALL be 50

#### Scenario: Leaving the field empty

- **WHEN** the user deletes all digits of the fee field and leaves the field without typing
- **THEN** the fee field SHALL show the computed fee again

#### Scenario: Minimum fee from the settings

- **WHEN** the saved odd-lot minimum fee is 5 and the user enters a buy of 5 shares at a price of 112.55 with a discount of 6
- **THEN** the fee field SHALL show 5

#### Scenario: Too many shares

- **WHEN** the user saves a record with 32768 shares
- **THEN** the system SHALL show an input error
- **AND** the system SHALL NOT write a record and SHALL NOT crash

## REMOVED Requirements

### Requirement: Choose the fee mode and discount in settings

**Reason**: The fixed-amount fee mode is removed, because brokers differ in their minimum fees and not in a flat fee per trade, and the settings now hold the discount and two minimum fees instead of a mode.
**Migration**: Use the requirement "Choose the fee discount and minimum fees in settings". The mode and the fixed amount that an earlier version saved are ignored and stay stored without being changed or deleted.
