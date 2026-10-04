<!-- SPECTRA:START v1.0.2 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `openspec/specs/`, change proposals in `openspec/changes/`.

## Use `/spectra-*` skills when:

- A discussion needs structure before coding → `/spectra-discuss`
- User wants to plan, propose, or design a change → `/spectra-propose`
- Tasks are ready to implement → `/spectra-apply`
- There's an in-progress change to continue → `/spectra-ingest`
- User asks about specs or how something works → `/spectra-ask`
- Implementation is done → `/spectra-archive`
- Commit only files related to a specific change → `/spectra-commit`

## Workflow

discuss? → propose → apply ⇄ ingest → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `openspec/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra-apply` and `/spectra-ingest` skills handle parked changes automatically.

<!-- SPECTRA:END -->

# Branch Convention

新需求（feature）必須在 `feature/{版號}/{需求名稱}` 分支上實作，例如 `feature/1.19/icloud-backup-rework`。版號採下一個預計發布的 App 版本（對照 `MARKETING_VERSION`）。

Bug 修正必須在 `fix/{版號}/{問題名稱}` 分支上實作，例如 `fix/1.19/duplicate-stockno-crash`。

## 版號規則

- 分支前綴的版號用 `MARKETING_VERSION` 寫法（`1.20`），不用 tag 寫法（`1.20.0`）
- 版號指「該分支預計隨哪個版本發布」：
  - 新需求：下一個尚未發布的版本。上一版（含 tag）已上傳後，改用下一版，例如 1.20 發版後開 `feature/1.21/...`，並把 `MARKETING_VERSION` 改為 1.21
  - 修正尚在 TestFlight 測試、未上架的版本：沿用該版號，例如 `fix/1.20/...`，只遞增 build number
  - 修正已上架版本的緊急 bug：用修訂版號，例如 `fix/1.20.1/...`，並把 `MARKETING_VERSION` 改為 1.20.1
- 已發版的分支不需要改名

## Tag 規則

- 格式 `v{MARKETING_VERSION}.{修訂}`，例如 `MARKETING_VERSION = 1.20` 對應 `v1.20.0`，1.20.1 對應 `v1.20.1`
- 只在 `release` 分支上打 tag；push `v*` tag 會觸發 `testflight.yml` 上傳 TestFlight（詳見 README「發版流程」）
- 同一版本因 TestFlight 問題重新上傳，用 GitHub Actions 的 Re-run，不要重打或移動 tag

## PR Merge 規則

- PR 一律用 **Merge commit**（`gh pr merge <N> --merge`），不用 squash 或 rebase，保留 feature／fix 分支上的 commit 歷史
- 合併前確認 CI（`build-and-test`）通過
- feature／fix 分支合併進 `mvvm`；發版時再把 `mvvm` merge 進 `release`（同樣用 merge commit）
- 上一個 PR 合併後，才從最新的 `mvvm` 切下一個分支，避免把未合併的 commit 帶進新分支

# Bug Fix Workflow

修 bug（含 crash report、tester 回報）必須依序：

1. 先寫一個能重現問題的測試（放在 `MyTaiwanStockTests/`），並執行確認它在修正前會失敗或 crash
2. 再修改程式碼
3. 重新執行該測試（以及同檔案的其他測試）確認通過，才算修復完成

無法寫自動化測試重現時（例如純 UI、系統行為），需在回報中說明原因與手動驗證方式。

# Code Review Workflow

Code review（含 subagent review）的結果必須記錄成 Markdown：

1. 存放於 `docs/reviews/{YYYY-MM-DD}-{主題}.md`，內容包含背景、依嚴重度分類的發現（附檔案位置與失敗情境）、已確認無問題的項目
2. 文件末尾將發現拆成「修復 Todo」checklist（`- [ ]`），每項對應一個可獨立驗證的修正
3. 逐項修復（仍須遵守上方 Bug Fix Workflow：先寫測試重現），每修完一項立即在文件中打勾（`- [x]`）
4. 決定不修的項目也要打勾，並註明原因
5. Review 文件是工作中的追蹤紀錄，不加入版控；所有項目都打勾後即刪除該文件

# Commit Message Convention

Commit 時必須使用 `git-commit` skill 撰寫 commit message，並額外遵守（skill 本身未涵蓋）：

- 不得提及 spectra task／change 名稱等 Spectra 內部追蹤資訊（例如 `Change: ...`、`Tasks: N/M complete`）
