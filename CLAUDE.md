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

# Commit Message Convention

Commit 時必須使用 `git-commit` skill 撰寫 commit message，並額外遵守（skill 本身未涵蓋）：

- 不得提及 spectra task／change 名稱等 Spectra 內部追蹤資訊（例如 `Change: ...`、`Tasks: N/M complete`）
