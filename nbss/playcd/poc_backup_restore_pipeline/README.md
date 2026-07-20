# NBSS Backup-Restore process - Proof of Concept

This documentation and code details the steps required to backup and restore an NBSS instance. The steps should be followed sequentially as follows

## Table of contents

1. [Backup NBSS manually](#1-manual-nbss-backup) (optional: only if scheduled overnight backup not available)
2. [Create zip file containing the required backup files](#2-zip-the-required-backup-files)
3. [Transfer the zip file to storage account, and its hash to key vault](#3-hash-zip-and-store-in-azure-key-vault)
4. Retrieve the file from storage
5. [Set up a clean Caché DB](#5-set-up-a-clean-caché-db)
6. Restore the backup using InterSystems restore process
7. Scrape the tables from Caché to csv

Details of each of the steps are set out below:

## 1. Manual NBSS backup

This section describes how to manually trigger a backup via the Caché Terminal. This should be run if the overnight backup has not completed before taking the [NBSS Zip Back Up](#2-zip-the-required-backup-files).

Open the Caché Terminal and run:

```Caché Terminal
ZN "%SYS"
DO ^BACKUP
```

The following menu will appear:

```OUTPUT
1) Backup
2) Restore ALL
3) Restore Selected or Renamed Directories
4) Edit/Display List of Directories for Backups
5) Abort Backup
6) Display Backup volume information
7) Monitor progress of backup or restore
```

Select `1`.

```OUTPUT
                 Cache Backup Utility
              --------------------------
What kind of backup:
   1. Full backup of all in-use blocks
   2. Incremental since last backup
   3. Cumulative incremental since last full backup
   4. Exit the backup program
1 =>
```

Select `1` — a full backup is currently used to capture everything.

```OUTPUT
Specify output device (type STOP to exit)
Device: c:\intersystems\cache\mgr\n =>
```

Type `BACKUP_CACHE.DAT`.

```OUTPUT
File exists, do you want to overwrite it <N>?Y
Backing up to device: c:\intersystems\cache\mgr\BACKUP_CACHE.DAT
Description:
```

Follow the remaining prompts as shown and the backup will commence.

```OUTPUT
Backing up the following directories:
 c:\intersystems\cache\mgr\
 c:\intersystems\cache\mgr\cache\
 c:\intersystems\cache\mgr\cacheaudit\
 c:\intersystems\cache\mgr\user\
 c:\nbss\cache\dem_app\
 c:\nbss\cache\dem_dat\

Start the Backup (y/n)? =>
```

Select `y` and the backup process will begin.

## 2. Zip the required backup files

### Overview

The `create_nbss_back_up.ps1` PowerShell script creates automated, timestamped backups of critical NBSS and InterSystems Caché database files.

1. **Stops the Caché instance** — Gracefully shuts down the running InterSystems Caché database
2. **Creates a compressed zip archive** containing:
   - NBSS\Attachments (all contents)
   - NBSS\Letters (all contents)
   - NBSS\Labels (all contents)
   - All CACHE.DAT database files from InterSystems\Cache
   - BACKUP_CACHE.DAT (the latest backup file)
3. **Saves the backup** with a timestamped filename: `NBSS_<BsoCode>_Backup_YYYYMMDD_HHmmss.zip`  (default: `NBSS_A000_Backup_YYYYMMDD_HHmmss.zip`)
4. **Restarts the Caché instance** — Automatically brings the database back online

This ensures you have a complete, point-in-time backup of your NBSS data and database state.

### Why Run Through the .bat File?

PowerShell has execution policies that prevent unsigned scripts from running by default. Running the script directly gives this error:

```output
The file is not digitally signed. You cannot run this script on the current system.
```

The `.bat` wrapper file (`create_nbss_back_up.bat`) **bypasses this restriction** by:

- Invoking PowerShell with `-ExecutionPolicy Bypass`
- Avoiding the need to alter system-wide security settings
- Allowing any user to run the backup without administrative PowerShell configuration

### Usage

#### Requirements

- **Administrator privileges** — The script must run as Administrator to stop/start the Caché service
- **InterSystems Caché** — Must be installed at the specified CacheRoot path
- **NBSS installation** — Must exist at the specified NbssRoot path
- **Backup Process** — A manual backup must have been recently run via the [NBSS Backup](#1-manual-nbss-backup) steps before proceeding

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BsoCode` | `A000` | BSO code embedded in the backup zip filename |
| `-NbssRoot` | `C:\NBSS` | Root folder where NBSS is installed |
| `-CacheRoot` | `C:\InterSystems` | Root folder where InterSystems Cache is installed |

#### Simple Usage (Recommended)

From `nbss/playcd/poc_backup_restore_pipeline`:

```PowerShell
.\create_nbss_back_up.bat
```

Runs with default paths and default BSO code (`A000`):

- NBSS: `C:\NBSS`
- InterSystems Cache: `C:\InterSystems`
- Output filename: `NBSS_A000_Backup_YYYYMMDD_HHmmss.zip`

#### With a BSO Code

```batch
.\create_nbss_back_up.bat -BsoCode "A0001344"
```

Output filename: `NBSS_A0001344_Backup_YYYYMMDD_HHmmss.zip`

#### With Custom Paths

```batch
.\create_nbss_back_up.bat -BsoCode "A0001344" -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"
```

#### With Only One Custom

```batch
.\create_nbss_back_up.bat -BsoCode "A0001344" -NbssRoot "D:\NBSS"
```

### Output

The script creates a zip file in the same directory as the batch file with the format `NBSS_A000_Backup_20260707_143015.zip` (using the default BSO code).

Example output:

```output
[14:30:15] NBSS root   : C:\NBSS
[14:30:15] Cache root  : C:\InterSystems
[14:30:15] Stopping Cache...
[14:30:20] Cache stopped.
[14:30:20] Creating zip: C:\path\to\NBSS_A000_Backup_20260707_1430.zip
[14:30:45] Added: NBSS\Attachments
[14:30:50] Added: Cache\mgr\CACHE.DAT (2500.5 MB)
[14:31:00] Added: Cache\mgr\BACKUP_CACHE.DAT (1200.3 MB)
[14:31:05] Backup complete: C:\path\to\NBSS_A000_Backup_20260707_143015.zip (3700.80 MB)
[14:31:10] Restarting Cache...
[14:31:15] Cache restarted successfully.
```

### Files

- `create_nbss_back_up.ps1` — The main PowerShell script (handles all backup logic)
- `create_nbss_back_up.bat` — Wrapper batch file (enables running without execution policy issues)

### Notes

- Caché will be unavailable during the backup process (typically a few minutes depending on database size)
- The backup process is automatic — Caché is restarted once the zip is created
- Ensure sufficient disk space for the backup file (typically 2-3x the CACHE.DAT size)
- Backups are timestamped (to the second), so you can safely run this multiple times without overwriting previous backups (unless started within the same second)

## 5. Set up a clean Caché DB

### Manual Approach

Using the PlayCD, follow these steps to set up a clean Caché install:

- Open PlayCD zip and open the `Cache` folder
- Run installer (cache-2018.1.4.505.1-win_x64.exe)
- Select 'Install New Instance'
- Name = CACHERESTORE (this can be whatever you want as long as it doesn't match the name of any existing Caché install)
- Install Folder = C:\InterSystems\CacheRestore\
- Click through remaining windows using the default options
- Once installed Cache services are available here: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Caché\CACHERESTORE

Note: Cache allows multiple installs on the same machine (and same drive). Once the service is running, the preferred Cache instance can be selected from the system tray (cube icon) in Windows.

### Using a Script

A PowerShell script is provided to automate the Caché installation silently — no manual clicking through the installer UI.

#### Step 1 — Extract the Caché installer

The installer `.exe` must be extracted from the PlayCD zip before it can be run:

```powershell
Expand-Archive "<path-to-zip-file>" -DestinationPath "C:\Temp\CacheInstaller"
```

The installer will be at `C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe`.

#### Step 2 — Run the silent install script

From `nbss/playcd/poc_backup_restore_pipeline`:

```powershell
.\install_cache_silent.bat -InstallerPath "C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe"
```

Or to install and restore a backup in one step:

```powershell
.\install_cache_silent.bat `
    -InstallerPath "C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe" `
    -BackupFile "<path-to-backup-file>"
```

- The installer also starts the Caché instance.
- Once installed Cache services are available here: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Caché\CACHERESTORE

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-InstallerPath` | *(required)* | Path to the extracted `cache-2018.1.4.505.1-win_x64.exe` |
| `-InstallDir` | `C:\InterSystems\CacheRestore` | Target installation directory |
| `-InstanceName` | `CACHERESTORE` | Name for the new Caché instance |
| `-SuperServerPort` | `1973` | TCP port for Caché SuperServer |
| `-WebServerPort` | `57773` | TCP port for Caché private web server |
| `-BackupFile` | *(none)* | Optional path to a `BACKUP_CACHE.DAT` to restore after install |
| `-SkipRestore` | `false` | If set, skips restore even when `-BackupFile` is provided |

#### Port conflicts

The script checks that the SuperServer and Web Server ports are free before installing. If your existing NBSS instance is already using a port, the script will fail with an error message telling you which process holds the port and suggesting an alternative:

```batch
.\install_cache_silent.bat -InstallerPath "..." -SuperServerPort 1974 -WebServerPort 57774
```

The default NBSS instance typically uses ports 1972/57772, so the defaults (1973/57773) should not conflict even with an existing NBSS/Caché install.

#### Files

- `install_cache_silent.ps1` — The main PowerShell script (handles install, port checks, and optional restore)
- `install_cache_silent.bat` — Wrapper batch file (enables running without execution policy issues)
