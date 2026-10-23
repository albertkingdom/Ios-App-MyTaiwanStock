## Problem

截圖匯入的股票名稱若被 Vision 拆為相鄰文字框，解析器只保留第一段文字，導致統一FANG+ 無法對應股號。使用者提供的裁切截圖在本機可辨識完整名稱，但股數 5 未被辨識，損益欄的 -- 被辨識為 11，解析器會錯誤取作股數。

## Root Cause

名稱合併僅支援獨立的加號，未處理中文、英文與數字片段。股數僅取交易類型後第一個整數，未確認其位於股數欄。

## Proposed Solution

合併名稱欄內相鄰的名稱片段，保留既有精確股號比對。以價格欄位置限制股數來源；缺失股數維持不完整，交由使用者在預覽頁補正。依 CLAUDE.md 先新增失敗測試、再修改解析器，最後重跑同檔所有測試。

## Non-Goals

不新增模糊名稱比對、不猜測漏讀的股數、不調整 Vision 語言設定、不上傳圖片、不改動交易儲存與 UI。

## Success Criteria

- 拆框的統一FANG+ 合併後能對應 00757；元大台灣與 50 合併後，價格仍取自價格欄。
- 使用者截圖的實際 Vision 文字框解析後日期為 2026-10-20、價格為 144.2，股數缺失，不得採用損益欄的 11。
- 原有收合、展開、截斷與獨立加號測試持續通過。

## Capabilities

### Modified Capabilities

- `trade-screenshot-import`: 明確定義拆框名稱重組與股數欄位隔離。

## Impact

- Affected code:
  - Modified: `MyTaiwanStock/Util/TradeScreenshotParser.swift`
  - Modified: `MyTaiwanStockTests/TradeScreenshotParserTests.swift`
  - Modified: `MyTaiwanStockTests/TradeScreenshotVisionFixtures.swift`
- Affected specs: `openspec/specs/trade-screenshot-import/spec.md`
