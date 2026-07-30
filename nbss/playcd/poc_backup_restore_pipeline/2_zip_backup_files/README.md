# 2. Zip the required backup files

## Overview

The `create_nbss_back_up.ps1` PowerShell script creates automated, timestamped backups of critical NBSS and InterSystems Caché database files.

1. **Stops the Caché instance** — Gracefully shuts down the running InterSystems Caché database
2. **Creates a compressed zip archive** containing:
   - NBSS\Attachments (all contents)
   - NBSS\Letters (all contents)
   - NBSS\Labels (all contents)
   - All CACHE.DAT database files from InterSystems\Cache
   - BACKUP_CACHE.DAT (the latest backup file)
3. **Saves the backup** with filename: `{YYYYMMDD}-{BsoCode}.zip`  (default: `{YYYYMMDD}-A000.zip`)
4. **Restarts the Caché instance** — Automatically brings the database back online

This ensures you have a complete, point-in-time backup of your NBSS data and database state.

## Why Run Through the .bat File?

PowerShell has execution policies that prevent unsigned scripts from running by default. Running the script directly gives this error:

```output
The file is not digitally signed. You cannot run this script on the current system.
```

The `.bat` wrapper file (`create_nbss_back_up.bat`) **bypasses this restriction** by:

- Invoking PowerShell with `-ExecutionPolicy Bypass`
- Avoiding the need to alter system-wide security settings
- Allowing any user to run the backup without administrative PowerShell configuration

## Usage

### Requirements

- **Administrator privileges** — The script must run as Administrator to stop/start the Caché service
- **InterSystems Caché** — Must be installed at the specified CacheRoot path
- **NBSS installation** — Must exist at the specified NbssRoot path
- **Backup Process** — A manual backup must have been recently run via the [NBSS Backup](../1_manual_nbss_backup/README.md) steps before proceeding

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BsoCode` | `A000` | BSO code embedded in the backup zip filename |
| `-NbssRoot` | `C:\NBSS` | Root folder where NBSS is installed |
| `-CacheRoot` | `C:\InterSystems` | Root folder where InterSystems Cache is installed |

### Simple Usage (Recommended)

From `nbss/playcd/poc_backup_restore_pipeline/2_zip_backup_files`:

```PowerShell
.\create_nbss_back_up.bat
```

Runs with default paths and default BSO code (`A000`):

- NBSS: `C:\NBSS`
- InterSystems Cache: `C:\InterSystems`
- Output filename: `{YYYYMMDD}-A000.zip`

### With a BSO Code

```batch
.\create_nbss_back_up.bat -BsoCode "A0001344"
```

Output filename: `{YYYYMMDD}-A0001344.zip`

### With Custom Paths

```batch
.\create_nbss_back_up.bat -BsoCode "A0001344" -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"
```

### With Only One Custom

```batch
.\create_nbss_back_up.bat -BsoCode "A0001344" -NbssRoot "D:\NBSS"
```

## Output

The script creates a zip file in `poc_backup_restore_pipeline` with the format `{YYYYMMDD}-A000.zip` (using the default BSO code).

Example output:

```output
[14:30:15] NBSS root   : C:\NBSS
[14:30:15] Cache root  : C:\InterSystems
[14:30:15] Stopping Cache...
[14:30:20] Cache stopped.
[14:30:20] Creating zip: C:\path\to\20260707-A000.zip
[14:30:45] Added: NBSS\Attachments
[14:30:50] Added: Cache\mgr\CACHE.DAT (2500.5 MB)
[14:31:00] Added: Cache\mgr\BACKUP_CACHE.DAT (1200.3 MB)
[14:31:05] Backup complete: C:\path\to\20260707-A000.zip (3700.80 MB)
[14:31:10] Restarting Cache...
[14:31:15] Cache restarted successfully.
```

## Files

- `create_nbss_back_up.ps1` — The main PowerShell script (handles all backup logic)
- `create_nbss_back_up.bat` — Wrapper batch file (enables running without execution policy issues)

## Notes

- Caché will be unavailable during the backup process (typically a few minutes depending on database size)
- The backup process is automatic — Caché is restarted once the zip is created
- Ensure sufficient disk space for the backup file (typically 2-3x the CACHE.DAT size)
- Running the script on the same day with the same BSO code will overwrite the previous backup for that day
