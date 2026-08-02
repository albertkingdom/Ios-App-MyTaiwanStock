# Multi-Agent Review Findings — rework-icloud-sync-to-backup

Review date: 2026-08-01
Method: 4 parallel subagent reviews (iCloud/CloudKit correctness, data-safety/schema, Swift concurrency, general code review + test coverage) against the uncommitted working tree.

Status of reviewed change: all tasks in `tasks.md` are marked `[x]`, but the findings below show real defects in the backup/restore mechanics that the existing tests do not catch.

## Critical — data corruption / loss risk

1. **Backup & restore bypass `NSFileCoordinator` entirely** (confirmed independently by 2 agents)
   - `BackupDestination.swift:27-37` (write) and `ICloudBackupService.swift:82-92` (restore) do plain `FileManager` remove/copy on files inside the ubiquitous container and on the live Core Data store — no coordination with iCloud's sync daemon or with Core Data's file access.
   - Restore deletes+replaces the store file the running `NSPersistentContainer` still has open, with no `remove(store)`/reload afterward. The in-memory SQLite connection keeps pointing at a stale file handle — the next write after a restore can corrupt the just-restored database or crash.

2. **WAL/SHM sidecar files are never backed up or restored**
   - Core Data's SQLite store uses WAL journaling by default. Only the main `.sqlite` file is copied — recent committed transactions living in `-wal` are silently dropped on backup; stale `-wal`/`-shm` files left behind on restore can cause SQLite to replay garbage against the new main file.

3. **Backup write isn't atomic**
   - `write()` does delete-then-copy in two separate steps (`BackupDestination.swift:33-36`). A kill/interruption between them leaves a truncated snapshot that a later restore will happily apply, corrupting the live DB. Should write-to-temp-then-`replaceItemAt`.

4. **Restoring an incompatible/older schema crashes on next launch**
   - No model-version check before overwrite. A resulting Core Data migration error isn't a `CKError`, so `LocalDBService`'s existing recovery path misses it and hits `fatalError` (`LocalDBService.swift:76`).

## High — concurrency races

5. **No re-entrancy guard on backup**
   - Double-tapping "立即備份" (`SettingViewController.swift:61`), or a manual backup overlapping with `sceneWillEnterForeground`'s auto-backup (`SceneDelegate.swift:97`), fire two concurrent `write()`/`restoreLatestSnapshot()` calls on the same file — compounds issues 1–3.

6. **Data race on `backgroundTaskID`**
   - `SceneDelegate.swift:117-129` — mutated from the `beginBackgroundTask` expiration closure (background thread) and from a `Task` continuation, with no synchronization. Can double-call `endBackgroundTask` or use a stale ID.

7. **Strong `self` capture across `await`**
   - `SettingViewController.swift:62-70` — navigating away mid-backup keeps the VC alive and can attempt to present an alert on a detached VC.

## Medium — correctness/logic

8. **`restoreLatestSnapshot()` skips the iCloud-availability check** that `backupIfNeeded`/`manualBackupNow` both do — inconsistent, and untested.

9. **Re-import prompt has no "already imported" guard**
   - `AccountViewController.offerLocalDataImportIfNeeded` re-fires on every login and only checks `fetchAllListFromDB().isEmpty`. Re-confirming re-uploads the same data to Firestore (duplicate risk), since local data is intentionally never marked/cleared after import.

10. **`sceneWillEnterForeground` mislabels its trigger reason**
    - Uses `.appLaunch` instead of a distinct foreground case (`SceneDelegate.swift:97`). Harmless today but defeats the extensibility the design doc calls for.

11. **Naming drift from the openspec proposal**
    - Spec calls for `protocol Clock` / `SystemClock`; code has `BackupClock` / `SystemBackupClock`. `tasks.md` item 1.1 is checked off despite the mismatch.

## Test coverage gaps

- `ICloudBackupServiceTests` covers throttling/first-backup/restore-happy-path well, but not restore failure paths (no snapshot, iCloud unavailable mid-restore, copy/remove throwing), and never exercises the real `ICloudDriveBackupDestination` or a real WAL-mode SQLite store — so it would not catch findings 1–4.
- `AccountViewControllerImportTests` never actually triggers the alert's confirm handler; the "decline" test is a no-op that doesn't touch the VC at all.
- No test for `SceneDelegate.offerICloudRestoreIfApplicable` or `triggerICloudBackupIfEnabled`'s background-task handling, despite being named directly in tasks.md 3.1/3.2/4.1.

## Recommendation

The service-layer throttling logic is solid and well-tested, but the file-level backup/restore mechanics (findings 1–4) have real data-corruption paths that should block shipping. Fix those first, then the concurrency guards (5–7), then the medium items.
