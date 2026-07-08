# NBSS Caché Export

## 1. Exporting code from Caché

In the Caché terminal, switch to the NBSS_DEM namespace:

```ObjectScript
ZN "NBSS_DEM"
```

Then export all classes, routines, and includes:

```ObjectScript
Set localFolder = "<INSERT LOCAL FOLDER>"
Do ##class(%SYSTEM.OBJ).Export("*.cls,*.mac,*.inc,",localFolder_"/all_files_export.xml")
```

NB: use '/' not '\' in filepaths.

### Unpacking

1. Move the exported XML file to `cache_export`
2. Run `uv run unpack_scripts.py`

This splits the large export into individual XML files organised by type (`cls/`, `mac/`, `inc/`).

## 2. Exporting data from Caché

Connects to NBSS_DEM via ODBC, fetches all tables and exports to CSV.

### Prerequisites

- Create a `.env` file in `nbss/playcd` and add the following:

```ENVIRONMENT
DRIVER=InterSystems ODBC
SERVER=127.0.0.1
PORT=1972
DATABASE=NBSS_DEM
UID=<username for NBSS_DEM data source>
PWD=<password for NBSS_DEM data source>
```

- (Optional) Within the local environment where Caché runs, set up the NBSS_DEM ODBC Data Source (Set up Part B - [ODBC Connector](https://nhsd-confluence.digital.nhs.uk/spaces/DTS/pages/1373789640/DSTA-554+Access+data+stored+in+Cache))

### Scraping Tables - Option 1: Windows with Caché running natively

**Problem**: Exporting the data is bit more complex as Caché installed `InterSystems ODBC` within `windows`. The repo is set to run with Linux (due to Make), however running this script via Linux (WSL) is difficult due to `InterSystems ODBC` only accessible via windows.

**_For meantime we will run this script via Powershell_**

Reference [InterSystem ODBC](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_loadlib)

- Run (via powershell due to ODBC connectors installed via Caché):

```PowerShell
cd nbss
Remove-Item -Recurse -Force .venv # if there is already .venv created
cd playcd
uv run export_app_tables.py
````

This will save the tables as .csv into the folder `\cache_data_export`

### Scraping Tables - Option 2: Mac with Caché running in Parallels

- In Parallels, install Python 32-bit: open powershell and run `winget install Python.Python.3.12 --architecture x86`
- Then run `py -3.12-32 -m pip install pyodbc python-dotenv`
- Open file explorer (in Windows) and find `dtos-breast-nbss-extraction\nbss\playcd`. Most likely in 'Home on Mac (Z:/)' drive. Copy the path (for example: `Z:\dtos-breast-nbss-extraction\nbss\playcd`).
- run `cd <path from above>`
- run `py -3.12-32 export_app_tables.py`

## NBSS Backup Script

### Overview

The `create_nbss_back_up.ps1` PowerShell script creates automated, timestamped backups of critical NBSS and InterSystems Caché database files.

1. **Stops the Caché instance** — Gracefully shuts down the running InterSystems Caché database
2. **Creates a compressed zip archive** containing:
   - NBSS\Attachments (all contents)
   - NBSS\Letters (all contents)
   - NBSS\Labels (all contents)
   - All CACHE.DAT database files from InterSystems\Cache
   - BACKUP_CACHE.DAT (the latest backup file)
3. **Saves the backup** with a timestamped filename: `NBSS_Backup_YYYYMMDD_HHmm.zip`
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

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-NbssRoot` | `C:\NBSS` | Root folder where NBSS is installed |
| `-CacheRoot` | `C:\InterSystems` | Root folder where InterSystems Cache is installed |

#### Simple Usage (Recommended)

```PowerShell
.\create_nbss_back_up.bat
```

Runs with default paths:

- NBSS: `C:\NBSS`
- InterSystems Cache: `C:\InterSystems`

#### With Custom Paths

```batch
.\create_nbss_back_up.bat -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"
```

#### With Only One Custom

```batch
.\create_nbss_back_up.bat -NbssRoot "D:\NBSS"
```

### Output

The script creates a zip file in the same directory as the batch file with the format `NBSS_Backup_20260707_143015.zip`

Example output:

```output
[14:30:15] NBSS root   : C:\NBSS
[14:30:15] Cache root  : C:\InterSystems
[14:30:15] Stopping Cache...
[14:30:20] Cache stopped.
[14:30:20] Creating zip: C:\path\to\NBSS_Backup_20260707_1430.zip
[14:30:45] Added: NBSS\Attachments
[14:30:50] Added: Cache\mgr\CACHE.DAT (2500.5 MB)
[14:31:00] Added: Cache\mgr\BACKUP_CACHE.DAT (1200.3 MB)
[14:31:05] Backup complete: C:\path\to\NBSS_Backup_20260707_1430.zip (3700.80 MB)
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
