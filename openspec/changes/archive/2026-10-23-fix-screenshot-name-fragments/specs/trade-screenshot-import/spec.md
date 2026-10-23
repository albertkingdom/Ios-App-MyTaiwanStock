## ADDED Requirements

### Requirement: Reassemble stock name fragments

The parser SHALL concatenate adjacent Chinese, Latin, numeric and plus-sign text fragments within the stock name column in left-to-right order before resolving the stock code. It SHALL preserve the price as a separate field and SHALL retain exact stock-name resolution without fuzzy matching.

#### Scenario: Chinese and Latin name fragments

- **WHEN** the name column contains adjacent boxes holding "統一", "FANG" and "+"
- **THEN** the parsed name SHALL be "統一FANG+" and resolve to stock code "00757"

#### Scenario: Numeric stock name suffix

- **WHEN** the name column contains adjacent boxes holding "元大台灣" and "50", followed by a price box holding "112"
- **THEN** the parsed name SHALL be "元大台灣50" and the price SHALL be 112

#### Scenario: Unrelated plus sign

- **WHEN** a plus-sign box lies outside the stock name column or is separated from the name by more than 0.03 of the image width
- **THEN** the parser SHALL NOT append it to the stock name

### Requirement: Exclude profit loss from share count

When the upper price column is available, the parser SHALL extract the share count only from the corresponding lower share column. Text from the profit/loss column SHALL NOT supply a missing share count. Missing shares SHALL leave the trade incomplete. When the upper row is absent, the parser SHALL preserve the existing incomplete-row behavior without borrowing fields from another row.

#### Scenario: Missing shares with a numeric profit loss observation

- **WHEN** the supplied 2026/10/20 screenshot produces price "144.20", stock name "統一FANG+", no observation for the displayed share count 5, and "11" in the profit/loss column
- **THEN** the trade SHALL have date 2026-10-20 and price 144.2
- **AND** its share count SHALL be absent rather than 11

#### Scenario: Original screenshots

- **WHEN** the original collapsed and expanded screenshot fixtures are parsed
- **THEN** the parsed share counts SHALL remain 5, 3, 1 and 10 for 元大台灣50, 華邦電, 台積電 and 瑞昱 respectively
