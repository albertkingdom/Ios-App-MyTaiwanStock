## Purpose

Defines how the app computes, stores, uploads and displays the brokerage fee and the securities transaction tax of each buy and sell record, and how they are merged into holdings, average buy price and profit.

## ADDED Requirements

### Requirement: Calculate fee and tax with one rule set

The system SHALL compute the fee and the transaction tax of a trade with one calculation that uses decimal arithmetic, and SHALL return no result when the price is not greater than 0 or the share count is less than 1. The trade value SHALL be the price multiplied by the number of shares, without rounding. A fee discount stored as a binary floating-point number SHALL be converted to a decimal through its shortest decimal text, so that a discount of 2.8 is exactly 2.8. In the discount mode, the fee SHALL be the trade value multiplied by 0.001425 and by the fee discount divided by 10, rounded down to a whole New Taiwan dollar, where a discount of 10 means no discount, and the fee SHALL then be raised to the minimum fee: 20 when the trade has 1000 shares or more, and 1 when the trade has fewer than 1000 shares. In the fixed-amount mode, the fee SHALL be the configured amount rounded down to a whole dollar and the minimum fee SHALL NOT apply. The tax SHALL be 0 for a buy. For a sell, the tax SHALL be the trade value multiplied by the tax rate of the chosen category, rounded down to a whole dollar, where the categories are general stock 0.3%, same-day stock trade 0.15%, ETF 0.1% and exempt 0%. A trade of 1000 shares or more that is not a multiple of 1000 SHALL use the whole-lot minimum fee.

#### Scenario: Buy without discount

- **WHEN** the user buys 1000 shares at a price of 100 with a discount of 10
- **THEN** the fee SHALL be 142 and the tax SHALL be 0

#### Scenario: Fee below the minimum is raised

- **WHEN** the user buys 1000 shares at a price of 20 with a discount of 6
- **THEN** the calculated fee of 17 SHALL be raised to the whole-lot minimum of 20

#### Scenario: Fixed amount replaces the formula

- **WHEN** the fee mode is the fixed amount with 30 dollars and the user buys 1000 shares at a price of 100
- **THEN** the fee SHALL be 30

#### Scenario: Saved fixed amount while the mode is discount

- **WHEN** a fixed amount of 30 was saved earlier but the fee mode is the discount mode
- **THEN** the fee SHALL be computed with the discount formula

#### Scenario: Decimal discount without a rounding error

- **WHEN** the discount is 2.8 and the user sells 1000 shares at a price of 1000
- **THEN** the fee SHALL be 399, not 398

#### Scenario: Invalid trade has no result

- **WHEN** the price is 0 or the share count is 0
- **THEN** the calculation SHALL return no fee and no tax

##### Example: fee and tax by trade

| Side | Shares | Price | Discount | Category | Fee | Tax |
| ---- | ------ | ----- | -------- | -------- | --- | --- |
| Buy | 1000 | 100 | 10 | general stock | 142 | 0 |
| Sell | 1000 | 105 | 6 | general stock | 89 | 315 |
| Buy | 5 | 112.55 | 6 | general stock | 1 | 0 |
| Sell | 10 | 757 | 6 | general stock | 6 | 22 |
| Buy | 1 | 2470 | 6 | general stock | 2 | 0 |
| Buy | 1000 | 20 | 6 | general stock | 20 | 0 |
| Sell | 2000 | 22 | 6 | ETF | 37 | 44 |
| Sell | 1000 | 100 | 10 | exempt | 142 | 0 |
| Buy | 999 | 1 | 10 | general stock | 1 | 0 |
| Buy | 1500 | 1 | 10 | general stock | 20 | 0 |

### Requirement: Choose the fee mode and discount in settings

The settings screen SHALL let the user choose the fee mode, either the discount mode or the fixed-amount mode. In the discount mode the user SHALL enter the fee discount as a number from 0.1 to 10 with at most two decimal places, where 10 means no discount. In the fixed-amount mode the user SHALL enter the fee amount as a number that is not negative, and the system SHALL round it down to a whole dollar. The system SHALL reject an amount that is not a number, is negative, or is above 2147483647, SHALL show an error and SHALL NOT save it. When no fee mode has been saved, the mode SHALL be the discount mode. When no discount has been saved, the discount SHALL be 10; when only the earlier discount choice, a whole-number position, was saved, the system SHALL read it as the discount equal to that position plus one, without changing what is stored.

#### Scenario: Decimal discount

- **WHEN** the user enters a discount of 2.8
- **THEN** the system SHALL compute fees with a discount of 2.8

#### Scenario: Discount out of range

- **WHEN** the user enters a discount of 0 or of 11
- **THEN** the system SHALL show an error and SHALL NOT save it

#### Scenario: Discount with three decimal places

- **WHEN** the user enters a discount of 2.855
- **THEN** the system SHALL show an error and SHALL NOT save it

#### Scenario: Earlier discount choice

- **WHEN** the earlier saved choice is the sixth entry and no new discount is saved
- **THEN** the discount SHALL be 6

#### Scenario: Fixed amount with a decimal point

- **WHEN** the user saves the fixed amount "20.5"
- **THEN** the fixed amount SHALL be 20

#### Scenario: Fixed amount that is not a number

- **WHEN** the user saves the fixed amount "abc"
- **THEN** the system SHALL show an error and SHALL NOT save it

#### Scenario: Existing users keep the discount formula

- **WHEN** a user who saved a fixed amount before the fee mode existed starts the app after the upgrade
- **THEN** the fee mode SHALL be the discount mode

### Requirement: Store fee and tax with each record

The system SHALL store the fee and the tax as optional whole-dollar numbers on each buy and sell record. A record without a stored fee or tax is a record whose fee or tax is unknown, and the system SHALL distinguish an unknown value from a stored value of 0. Records created by manual entry or by screenshot import SHALL carry the fee and the tax that were shown to the user when the record was saved. A record created by manual entry or by screenshot import SHALL always have a fee and a tax; only records saved before this capability have unknown values. The tax of a buy record SHALL always be stored as 0.

#### Scenario: New record keeps the shown values

- **WHEN** the user saves a sell of 10 shares at 757 with the fee field showing 6 and the tax field showing 22
- **THEN** the stored record SHALL have a fee of 6 and a tax of 22

#### Scenario: Existing record has unknown fee

- **WHEN** a record that was saved before this capability exists is displayed
- **THEN** its fee and tax SHALL be unknown, SHALL be shown as a dash, and SHALL NOT be shown as 0

### Requirement: Keep existing data when the database is upgraded

When the app starts with a database that was created before fee and tax were stored, the system SHALL keep every existing record unchanged and SHALL leave the new fee and tax values of those records unknown. The system SHALL NOT delete or reset the database to perform the upgrade.

#### Scenario: Upgrade with existing records

- **GIVEN** a database with three buy records and two sell records created before this capability
- **WHEN** the app starts after the upgrade
- **THEN** all five records SHALL be present with the same stock number, price, shares, date and side
- **AND** the fee and tax of all five SHALL be unknown

### Requirement: Upload fee and tax to Firestore

When a record is uploaded to Firestore, the system SHALL include the fee and the tax in the document when they are known and SHALL omit them when they are unknown. This SHALL apply to a record saved by manual entry, a record saved by screenshot import, and a local record uploaded when the user signs in and chooses to import local data. The system SHALL NOT download history records from Firestore as part of this capability.

#### Scenario: Upload with fee and tax

- **WHEN** a record with a fee of 6 and a tax of 22 is uploaded
- **THEN** the document SHALL contain the fee 6 and the tax 22 together with the existing fields

#### Scenario: Upload with unknown fee

- **WHEN** a record whose fee and tax are unknown is uploaded
- **THEN** the document SHALL contain no fee field and no tax field

#### Scenario: Local data imported after sign-in

- **WHEN** the user signs in and imports a local record that has a fee of 142
- **THEN** the uploaded document SHALL contain the fee 142

### Requirement: Enter fee and tax when adding a record by hand

On the add-record screen the system SHALL compute the fee from the final text of the price and shares fields, using the fee mode and settings from the settings screen, every time the price or the shares change, when the side changes between buy and sell, and when the tax category changes. The fee and the tax SHALL be shown in editable fields that contain only the number; the unit SHALL be shown beside the field. For a sell, the system SHALL show the tax field and a choice of tax category with general stock as the default and SHALL compute the tax from the chosen category; for a buy the system SHALL NOT show a tax field and SHALL store a tax of 0. When the user types in the fee field or the tax field, that field SHALL keep the user's value when the price, the shares, the side or the category change afterwards. While the user is editing, an empty field SHALL stay empty so that a new number can be typed, and when the user leaves a field that is still empty the system SHALL show the computed value again and SHALL compute that field automatically again. The system SHALL store the values shown in the fields. The system SHALL reject a share count above 32767, and a fee or tax that is negative, not a whole number, or above 2147483647, SHALL show an input error for it and SHALL NOT write a record.

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

#### Scenario: Too many shares

- **WHEN** the user saves a record with 32768 shares
- **THEN** the system SHALL show an input error
- **AND** the system SHALL NOT write a record and SHALL NOT crash

### Requirement: Compute holdings and cost with sells and fees

For one stock, the system SHALL compute the holdings as the total shares bought minus the total shares sold, and SHALL show a negative result as it is. The system SHALL compute the average buy price including fees as the sum of the buy values and the buy fees divided by the total shares bought, where an unknown fee counts as 0, and SHALL show it as a dash when there are no buys. The average sell price SHALL be the sum of the sell values divided by the total shares sold, without fees, and SHALL be shown as a dash when there are no sells. The system SHALL show average prices rounded half up to two decimal places. The market value SHALL be shown only when the holdings are greater than 0, and as a dash otherwise. For a buy record, the profit percentage SHALL be the current price minus the fee-inclusive unit cost, divided by the fee-inclusive unit cost, multiplied by 100, where the fee-inclusive unit cost is the buy value plus the fee, divided by the shares. The profit percentage SHALL be derived from a number, so that a positive value and a negative value are shown in their own colors. A sell record SHALL keep showing no profit percentage. The stock detail screen SHALL label the average buy price as including fees. When the average buy price changes to a dash, the screen SHALL update the label to the dash.

#### Scenario: Buy and sell the same shares

- **WHEN** the user bought 1000 shares at 100 and sold 1000 shares at 105
- **THEN** the holdings SHALL be 0
- **AND** the average buy price SHALL be 100 plus the buy fee divided by 1000

#### Scenario: Partial sell

- **WHEN** the user bought 1000 shares and sold 400 shares
- **THEN** the holdings SHALL be 600

#### Scenario: Only sell records

- **WHEN** a stock has only sell records
- **THEN** the holdings SHALL be shown as negative, the market value SHALL be shown as a dash, and the average buy price SHALL be shown as a dash
- **AND** the system SHALL NOT divide by zero

#### Scenario: Last buy is deleted

- **WHEN** the user deletes the only buy record of a stock that also has a sell record
- **THEN** the average buy price label SHALL change to a dash and SHALL NOT keep the earlier value

##### Example: average buy price including fees

- **GIVEN** a buy of 1000 shares at 100 with a fee of 142, and a buy of 1000 shares at 110 with a fee of 156
- **WHEN** the stock detail screen is shown
- **THEN** the average buy price including fees SHALL be 105.149, shown as 105.15

##### Example: rounding of an average price

- **GIVEN** a buy of 1000 shares at 100 with a fee of 145
- **WHEN** the stock detail screen is shown
- **THEN** the average buy price including fees SHALL be 100.145, shown as 100.15

##### Example: profit of a buy record

- **GIVEN** a buy of 1000 shares at 100 with a fee of 142 and a current price of 105
- **WHEN** the record is shown
- **THEN** the profit percentage SHALL be 4.85 percent, shown in the color of a positive value

### Requirement: Show fee and tax per record and flag missing fee data

The records list of the stock detail screen SHALL show the fee and the tax of each record on a second line of the record row, with a dash for an unknown value, and SHALL remain readable at the largest Dynamic Type size without truncating the first line. When at least one buy record of the stock has an unknown fee, the stock detail screen SHALL show a note next to the average buy price that some records have no fee data. Sell records with an unknown fee SHALL NOT cause the note.

#### Scenario: Mixed buy records

- **WHEN** a stock has one buy record with a stored fee and one buy record from before this capability
- **THEN** the first record SHALL show its fee, the second SHALL show a dash, and the note SHALL be shown

#### Scenario: Old sell record only

- **WHEN** the only record without a fee is a sell record
- **THEN** the note SHALL NOT be shown
