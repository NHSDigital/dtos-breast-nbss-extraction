# 7. Restore the backup onto a clean Caché installation

> **IMPORTANT:** This will not work if there is another NBSS or Caché installation on this machine. Please uninstall NBSS and Caché delete any `C:\NBSS\` and `C:\InterSystems\` folders before starting. NBSS hard-codes paths (e.g. `C:\NBSS\`, registry keys) which will conflict with the restore target and cause both installations to break.

## Overview

The `restore_nbss_back_up.ps1` PowerShell script restores an NBSS backup zip (created by `create_nbss_back_up.ps1`) onto a clean InterSystems Caché installation.

The NBSS databases (`dem_app`, `dem_dat`) live under `C:\NBSS\Cache\` on the source system — they are **not** among the `CACHE.DAT` cold-backup files in the zip (which are from `C:\InterSystems\Cache\`). The NBSS data is only captured inside `BACKUP_CACHE.DAT` (the Caché online backup output).

The script performs the restore in a mix of automated and interactive steps:

1. **Extracts `BACKUP_CACHE.DAT`** from the backup zip into the Caché `mgr\` directory
2. **Extracts NBSS application files** (Attachments, Letters, Labels) to `NbssRoot`
3. **Starts the Caché instance** (leaving the clean install's system databases intact)
4. **Creates and mounts empty databases** for `dem_app` and `dem_dat` (so `^DBREST` can write to them)
5. **Opens an interactive `^DBREST` session** — the user follows on-screen prompts to restore the NBSS databases (skipping system databases)
6. **Creates an `NBSS` namespace** mapped to the restored databases

> **IMPORTANT:** The script does NOT restore system databases (`CACHESYS`, `CACHELIB`, `CACHEAUDIT`, etc.). Restoring these from a different instance causes `cache.cpf` parsing errors and prevents startup. Only the NBSS application databases are restored via `^DBREST`.

## Prerequisites

- A **clean InterSystems Caché installation** must already exist at the specified `CacheRoot` path (e.g. `C:\InterSystems\CacheRestore`)
- The target Caché instance must use the **same version, character width (8-bit or Unicode), and locale** as the source instance
- **Administrator privileges** are required to stop/start the Caché service
- A backup zip file (e.g. `20260708-A0001344.zip`) must be available locally

## Usage

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-BackupZip` | Yes | — | Path to the NBSS backup zip file |
| `-NbssRoot` | No | `C:\NBSS` | Root folder where NBSS application files should be restored |
| `-CacheRoot` | No | `C:\InterSystems\CacheRestore` | Path to the Caché instance folder |
| `-InstanceName` | No | `CACHERESTORE` | Name of the Caché instance |
| `-NbssDbDir` | No | `C:\NBSS\Cache` | Directory where NBSS databases (`dem_app`, `dem_dat`) will be created |
| `-SkipNbssFiles` | No | — | If specified, skips restoring Attachments/Letters/Labels |

### Simple Usage (Recommended)

From `nbss/playcd/poc_backup_restore_pipeline/7_restore_backup`:

```batch
.\restore_nbss_back_up.bat -BackupZip "..\20260708-A0001344.zip"
```

### With Custom Paths

```batch
.\restore_nbss_back_up.bat -BackupZip "D:\Backups\20260708-A0001344.zip" -CacheRoot "E:\InterSystems\CacheRestore" -NbssRoot "D:\NBSS"
```

### Database Only (Skip NBSS Application Files)

```batch
.\restore_nbss_back_up.bat -BackupZip "..\20260708-A0001344.zip" -SkipNbssFiles
```

## Example Output

```output
[10:15:00] Backup zip   : C:\path\to\20260708-A0001344.zip
[10:15:00] NBSS root    : C:\NBSS
[10:15:00] Cache root   : C:\InterSystems\CacheRestore
[10:15:00] Instance     : CACHERESTORE
[10:15:00] NBSS DB dir  : C:\NBSS\Cache
[10:15:00] Checking if instance CACHERESTORE is running...
[10:15:00] Instance CACHERESTORE is not running -- skipping stop.
[10:15:00] Opening backup zip...
[10:15:30] Extracted: BACKUP_CACHE.DAT (1066.9 MB) -> C:\InterSystems\CacheRestore\mgr\BACKUP_CACHE.DAT
[10:15:30] Extraction complete: BACKUP_CACHE.DAT + 23 NBSS file(s)
[10:15:30] Starting instance CACHERESTORE...
[10:15:35] Instance CACHERESTORE started successfully.
[10:15:35] Creating, registering and mounting NBSS databases...
[10:15:36]   Databases created and mounted successfully.
[10:15:36]
[10:15:36] ============================================================
[10:15:36] INTERACTIVE STEP: ^DBREST
[10:15:36] ============================================================
[10:15:36] ...prompts displayed...
[10:15:36] Launching interactive csession for ^DBREST...
```

At this point a Caché terminal opens. Follow the prompts below, then the script continues automatically.

## Running ^DBREST (interactive step)

When the Caché terminal opens, type `DO ^DBREST` and respond to each prompt as shown:

| Prompt | Your response |
|--------|---------------|
| `1 =>` | `2` |
| `Do you want to set switch 10...? Yes =>` | press Enter |
| `Device:` | `C:\InterSystems\CacheRestore\mgr\BACKUP_CACHE.DAT` |
| `Is this the backup you want to start restoring? Yes =>` | press Enter |
| `c:\intersystems\cache\mgr\ =>` | `X` |
| `c:\intersystems\cache\mgr\cacheaudit\ =>` | `X` |
| `c:\intersystems\cache\mgr\user\ =>` | `X` |
| `c:\nbss\cache\dem_app\ =>` | `C:\NBSS\Cache\dem_app\` |
| `c:\nbss\cache\dem_dat\ =>` | `C:\NBSS\Cache\dem_dat\` |
| `Do you want to change this list of directories? No =>` | press Enter |
| `Confirm Restore? No =>` | `Yes` |
| *(restore runs — wait for it to finish)* | |
| `Device:` (next backup volume) | `STOP` |
| `Do you have any more backups to restore? Yes =>` | `No` |
| `Apply: 1 =>` (journal entries) | `4` |

Then type `HALT` to exit the Caché terminal. The script will continue with namespace creation.

## Files

- `restore_nbss_back_up.ps1` — The main PowerShell restore script
- `restore_nbss_back_up.bat` — Wrapper batch file (enables running without execution policy issues)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ccontrol.exe not found` | Verify `-CacheRoot` points to the Caché instance folder (e.g. `C:\InterSystems\CacheRestore`) |
| `cache.cpf` parsing errors on start | You likely restored `mgr\CACHE.DAT` (CACHESYS) from the source — reinstall the Caché instance and re-run the script |
| `*ReadOnly` error in ^DBREST | The target databases weren't created/mounted. Check `%TEMP%\setup_db_output.txt` for errors from step 4 |
| Namespace not found after restore | Check `%TEMP%\cache_config_output.txt` for errors from the namespace creation step |
| Character/locale mismatch errors | The target Caché instance must match the source's character width and locale setting |
