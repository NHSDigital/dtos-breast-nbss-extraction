# NBSS Backup-Restore process - Proof of Concept

This documentation and code details the steps required to backup and restore an NBSS instance. The steps should be followed sequentially as follows

## Table of contents

1. [Backup NBSS manually](#1-manual-nbss-backup) (optional: only if scheduled overnight backup not available)
2. [Create zip file containing the required backup files](#2-zip-the-required-backup-files)
3. [Hash the zip and store the hash in Azure Key Vault](#3-hash-the-zip-and-store-the-hash-in-azure-key-vault)
4. [Transfer the zip file to Azure Storage](#4-transfer-the-zip-file-to-azure-storage)
5. [Retrieve the file from storage and verify integrity](#5-retrieve-the-file-from-storage-and-verify-integrity)
6. [Set up a clean Caché DB](#6-set-up-a-clean-caché-db)
7. [Restore the backup onto a clean Caché installation](#7-restore-the-backup-onto-a-clean-caché-installation)
8. [Verify database integrity](#8-verify-database-integrity)
9. [Scrape the tables from Caché to CSV](#9-scrape-the-tables-from-caché-to-csv)

Details of each of the steps are set out below:

## Naming convention

A consistent naming pattern is used across all steps to ensure the hash stored in Key Vault can be matched to the correct blob in storage. The pattern is:

| Artifact | Format | Example |
|----------|--------|---------|
| Zip filename (uploaded to storage) | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |
| Key Vault secret name | `{YYYYMMDD}-{BsoCode}-hash` | `20260715-A0001344-hash` |
| Blob name in storage container | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |

The download script (step 4) derives the secret name by stripping the `.zip` extension from the blob name and appending `-hash`. For this to work, the blob uploaded in step 3 **must** be renamed to `{YYYYMMDD}-{BsoCode}.zip` before uploading via AzCopy.

> **Important:** The zip file created in step 2 uses the format `NBSS_<BsoCode>_Backup_YYYYMMDD_HHmmss.zip`. You must rename it to `{YYYYMMDD}-{BsoCode}.zip` before uploading to storage so the naming is consistent with the Key Vault secret.

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

## 3. Hash the zip and store the hash in Azure Key Vault

### Overview

The `transfer_hash_zip.ps1` PowerShell script computes a SHA-256 hash of the backup zip file and stores it as a secret in Azure Key Vault. This allows the integrity of the backup to be verified at any point — if the hash stored in Key Vault matches the hash of the file you download, the file has not been tampered with or corrupted.

1. **Resolves the zip file** — Uses the path supplied via `-ZipPath`, or auto-selects the most recently modified `*.zip` in the script directory
2. **Computes a SHA-256 hash** — Produces a unique fingerprint of the file contents
3. **Checks Azure CLI login** — Automatically launches `az login` if not already authenticated
4. **Stores the hash in Key Vault** — Creates a secret named `{YYYYMMDD}-{BsoCode}-hash` e.g. `20260715-A0001344-hash`

Each zip file produces a different hash because the zip embeds the timestamp of when files were compressed, ensuring the value stored in Key Vault always reflects that specific backup.

### Why Run Through the .bat File?

The `.bat` wrapper (`transfer_hash_zip.bat`) bypasses PowerShell execution policy restrictions — the same reason as `create_nbss_back_up.bat`. See [Why Run Through the .bat File?](#why-run-through-the-bat-file) above.

### Requirements

- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>
- **Azure Key Vault access** — The authenticated identity must have the **Key Vault Secrets Officer** role on the target vault
- **A zip file** — Produced by `create_nbss_back_up.bat` in the previous step

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BsoCode` | *(mandatory)* | BSO code embedded in the secret name e.g. `A0001344` |
| `-KeyVaultName` | `nbsse-dev-kv` | Name of the Azure Key Vault |
| `-ZipPath` | *(newest `*.zip` in script folder)* | Full path to the zip file to hash |

### Usage

From `nbss/playcd/poc_backup_restore_pipeline`:

#### Simple (auto-detects newest zip)

```PowerShell
.\transfer_hash_zip.bat A0001344
```

#### With explicit zip path

```PowerShell
.\transfer_hash_zip.bat A0001344 "C:\path\to\NBSS_A0001344_Backup_20260715_143015.zip"
```

#### With a different Key Vault

```PowerShell
.\transfer_hash_zip.ps1 -BsoCode "A0001344" -KeyVaultName "my-other-kv" -ZipPath "C:\path\to\backup.zip"
```

### Output

```output
Zip file   : C:\...\NBSS_A0001344_Backup_20260715_143015.zip
SHA-256    : ....
Secret name: 20260715-A0001344-hash
Azure CLI  : logged in as user@nhs.net
Storing secret in Key Vault 'nbsse-dev-kv' ...
Secret stored successfully.
Secret ID  : https://nbsse-dev-kv.vault.azure.net/secrets/20260715-A0001344-hash/...
```

### Files

- `transfer_hash_zip.ps1` — The main PowerShell script (hashing and Key Vault logic)
- `transfer_hash_zip.bat` — Wrapper batch file (enables running without execution policy issues)

### Notes

- Key Vault secret names only allow **letters, numbers, and hyphens** — underscores are not permitted
- Running the script on the same day with the same BSO code will **overwrite** the existing secret for that day. Use `-ZipPath` explicitly if running multiple times per day to ensure the correct file is hashed
- The script will prompt for `az login` automatically if you are not already authenticated

## 4. Transfer the zip file to Azure Storage

Reference: [SAS token generation](../sas_service_token_script/sas-token-generation.md)
You need to have Azure CLI installed and be logged in on your Microsoft Entra account to access the account keys for the storage account.

### Requirements

- **AzCopy** — Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>
- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>

### Usage

Run the shell script interactively to be prompted to input the storage account name and container name.

| Variable | Value | Description |
|-----------|---------|-------------|
| `-storage_account` | `bsrtestdatalake` | Storage account to copy the file to |
| `-container_name` | `bso-001-container` | Name of the container we are copying to |
| `-local path to file to upload` | *(newest `*.zip` in script folder)* | Full path to the hashed zip file |

```shell
bash generate-container-sas-token.sh
```

Run the shell script non-interactively by providing parameters:

```shell
bash generate-container-sas-token.sh <storage_account> <container_name>
```

Once the command is run, if you have the correct permissions and the right account/container names, the command will return a raw string which is the SAS token. Copy this token to use in the AzCopy operation.

Fill the command with the relevant info and append the SAS token to the end. The easiest way to upload the file is to run the AzCopy command from the same directory as the file and just specify the file name in the local path to file section.

```shell
AzCopy copy "<local path to file to upload>" "https://<storageaccount name>.blob.core.windows.net/<storagecontainer name>?<sas token>"
```

Once run, if successful, you should see the command return that it has done a write operation to the storage container.

## 5. Retrieve the file from storage and verify integrity

### Overview

The `download_latest_blob.ps1` PowerShell script downloads the most recently modified blob from an Azure Storage Account container, computes its SHA-256 hash, and compares it against the hash stored in Azure Key Vault to verify the file has not been tampered with or corrupted during transfer.

1. **Downloads the latest blob** — Lists all blobs in the specified container, identifies the most recently modified, and downloads it to the script directory
2. **Computes a SHA-256 hash** — Produces a fingerprint of the downloaded file
3. **Retrieves the stored hash from Key Vault** — Uses the zip filename (without extension) + `-hash` as the secret name
4. **Compares the hashes** — If they match, the file integrity is confirmed; if not, the script exits with an error

### Requirements

- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>
- **Azure login** — Run `az login` before executing the script
- **Storage Account access** — The authenticated identity must have read access to the storage container
- **Key Vault access** — The authenticated identity must have the **Key Vault Secrets User** role on the target vault

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ContainerName` | *(mandatory)* | Name of the Azure Storage container |
| `-StorageAccountName` | *(mandatory)* | Name of the Azure Storage Account |
| `-KeyVaultName` | `nbsse-dev-kv` | Name of the Azure Key Vault to retrieve the stored hash from |

### Why Run Through the .bat File?

The `.bat` wrapper (`download_latest_blob.bat`) bypasses PowerShell execution policy restrictions — the same reason as `create_nbss_back_up.bat`. See [Why Run Through the .bat File?](#why-run-through-the-bat-file) above.

### Usage

From `nbss/playcd/poc_backup_restore_pipeline`:

#### Simple (default Key Vault)

```PowerShell
.\download_latest_blob.bat bso-001-container bsrtestdatalake
```

#### With a different Key Vault

```PowerShell
.\download_latest_blob.bat bso-001-container bsrtestdatalake my-other-kv
```

#### Running the PowerShell script directly

```PowerShell
.\download_latest_blob.ps1 -ContainerName "bso-001-container" -StorageAccountName "bsrtestdatalake"
```

### Output

```output
Latest blob: 20260715-A0001344.zip
Download complete: C:\...\poc_backup_restore_pipeline\20260715-A0001344.zip
SHA-256    : ...
Secret name: 20260715-A0001344-hash
Stored hash: ...
MATCH: Downloaded file hash matches the stored hash.
```

If the hashes do not match:

```output
WARNING: MISMATCH: Downloaded file hash does NOT match the stored hash.
  Local : ABC123...
  Stored: DEF456...
```

### Files

- `download_latest_blob.ps1` — The main PowerShell script (download, hash, and verify logic)
- `download_latest_blob.bat` — Wrapper batch file (enables running without execution policy issues)

### Notes

- The file is downloaded to the same directory as the script
- The secret name is derived from the blob filename: `{filename-without-extension}-hash` e.g. blob `20260715-A0001344.zip` → secret `20260715-A0001344-hash`
- If the container has multiple blobs, the most recently modified one is selected
- A hash mismatch indicates the file may have been corrupted or tampered with — do not proceed with the restore

## 6. Set up a clean Caché DB

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

#### Port conflicts

The script checks that the SuperServer and Web Server ports are free before installing. If your existing NBSS instance is already using a port, the script will fail with an error message telling you which process holds the port and suggesting an alternative:

```batch
.\install_cache_silent.bat -InstallerPath "..." -SuperServerPort 1974 -WebServerPort 57774
```

The default NBSS instance typically uses ports 1972/57772, so the defaults (1973/57773) should not conflict even with an existing NBSS/Caché install.

#### Files

- `install_cache_silent.ps1` — The main PowerShell script (handles install and port checks)
- `install_cache_silent.bat` — Wrapper batch file (enables running without execution policy issues)

## 7. Restore the backup onto a clean Caché installation

> **IMPORTANT:** This will not work if there is another NBSS or Caché installation on this machine. Please uninstall NBSS and Caché delete any `C:\NBSS\` and `C:\InterSystems\` folders before starting. NBSS hard-codes paths (e.g. `C:\NBSS\`, registry keys) which will conflict with the restore target and cause both installations to break.

### Overview

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

### Prerequisites

- A **clean InterSystems Caché installation** must already exist at the specified `CacheRoot` path (e.g. `C:\InterSystems\CacheRestore`)
- The target Caché instance must use the **same version, character width (8-bit or Unicode), and locale** as the source instance
- **Administrator privileges** are required to stop/start the Caché service
- A backup zip file (e.g. `NBSS_Backup_20260708_152359.zip`) must be available locally

### Usage

#### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-BackupZip` | Yes | — | Path to the NBSS backup zip file |
| `-NbssRoot` | No | `C:\NBSS` | Root folder where NBSS application files should be restored |
| `-CacheRoot` | No | `C:\InterSystems\CacheRestore` | Path to the Caché instance folder |
| `-InstanceName` | No | `CACHERESTORE` | Name of the Caché instance |
| `-NbssDbDir` | No | `C:\NBSS\Cache` | Directory where NBSS databases (`dem_app`, `dem_dat`) will be created |
| `-SkipNbssFiles` | No | — | If specified, skips restoring Attachments/Letters/Labels |

#### Simple Usage (Recommended)

From `nbss/playcd/poc_backup_restore_pipeline`:

```batch
.\restore_nbss_back_up.bat -BackupZip ".\NBSS_Backup_20260708_152359.zip"
```

#### With Custom Paths

```batch
.\restore_nbss_back_up.bat -BackupZip "D:\Backups\NBSS_A0001344_Backup_20260708_152359.zip" -CacheRoot "E:\InterSystems\CacheRestore" -NbssRoot "D:\NBSS"
```

#### Database Only (Skip NBSS Application Files)

```batch
.\restore_nbss_back_up.bat -BackupZip ".\NBSS_Backup_20260708_152359.zip" -SkipNbssFiles
```

### Example Output

```output
[10:15:00] Backup zip   : C:\path\to\NBSS_Backup_20260708_152359.zip
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

### Running ^DBREST (interactive step)

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

### Files

- `restore_nbss_back_up.ps1` — The main PowerShell restore script
- `restore_nbss_back_up.bat` — Wrapper batch file (enables running without execution policy issues)

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `ccontrol.exe not found` | Verify `-CacheRoot` points to the Caché instance folder (e.g. `C:\InterSystems\CacheRestore`) |
| `cache.cpf` parsing errors on start | You likely restored `mgr\CACHE.DAT` (CACHESYS) from the source — reinstall the Caché instance and re-run the script |
| `*ReadOnly` error in ^DBREST | The target databases weren't created/mounted. Check `%TEMP%\setup_db_output.txt` for errors from step 4 |
| Namespace not found after restore | Check `%TEMP%\cache_config_output.txt` for errors from the namespace creation step |
| Character/locale mismatch errors | The target Caché instance must match the source's character width and locale setting |

## 8. Verify database integrity

After the restore completes, run `run_integrity_check.ps1` to verify the structural integrity of the restored NBSS databases (`dem_app` and `dem_dat`).

This checks that all database blocks are self-consistent and all globals are traversable — confirming the backup wasn't corrupted during transfer or restoration.

### Usage

From `nbss/playcd/poc_backup_restore_pipeline`:

```batch
.\run_integrity_check.bat
```

Or with custom parameters:

```batch
.\run_integrity_check.bat -CacheRoot "E:\InterSystems\CacheRestore" -TimeoutSeconds 900
```

### What happens

- The script calls `Do Silent^Integrity(logfile, dirlist)` in the `%SYS` namespace
- It runs in the background and writes results to `<CacheRoot>\mgr\integ_nbss.txt`
- The script polls the log file until it completes (default timeout: 10 minutes)
- A summary is printed showing totals per directory and whether errors were found

### Interpreting results

The output shows a summary per directory:

```output
---Total for directory C:\NBSS\Cache\dem_app\---
       128 Pointer Level blocks        1024kb (49% full)
    34,608 Data Level blocks            270MB (73% full)
     4,538 Big String blocks             35MB (85% full) # = 1,828
    39,289 Total blocks                 306MB (75% full)
     1,543 Free blocks                   12MB

Elapsed time = 0.6 seconds 07/22/2026 14:37:17

No Errors were found in this directory.
```

Exit codes: `0` = passed, `1` = timeout, `2` = errors found.

### Running interactively

If you need a more detailed check:

```Caché Terminal
ZN "%SYS"
DO ^Integrity
```

Follow the prompts to select the NBSS databases.

### Files

- `run_integrity_check.ps1` — The main PowerShell integrity check script
- `run_integrity_check.bat` — Wrapper batch file (enables running without execution policy issues)

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Integrity check timeout | Check log manually at `<CacheRoot>\mgr\integ_nbss.txt` — large databases may take longer |
| Integrity errors found | Do NOT use the database. Re-download the backup zip, verify its hash, and re-run the restore |

### Reference

- [InterSystems: Verifying Structural Integrity](https://docs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_integrity#GCDI_integrity_verify)

## 9. Scrape the tables from Caché to CSV

### Overview

The `export_app_tables.py` script connects to the restored CACHERESTORE instance via ODBC, fetches all base tables from all schemas, and exports each table to a CSV file. Empty tables are also exported to preserve the schema structure.

The script:

1. **Connects** to Caché via ODBC using credentials from a `.env` file
2. **Queries `INFORMATION_SCHEMA.TABLES`** to discover all base tables
3. **Exports each table** in chunks (10,000 rows at a time) to avoid memory issues
4. **Organises output** into `cache_data_export/<schema>/<table>.csv`

### Prerequisites

- The CACHERESTORE instance must be running with the NBSS namespace available (steps 6–8 completed)
- The InterSystems ODBC driver must be installed (this is included with the Caché installation)
- Create a `.env` file in `nbss/playcd/poc_backup_restore_pipeline` with the following:

```ENVIRONMENT
DRIVER=InterSystems ODBC
SERVER=localhost
PORT=1973
DATABASE=NBSS
UID=_SYSTEM
PWD=<password for the CACHERESTORE instance>
```

> **Note:** The default `_SYSTEM` password for a fresh Caché install is `SYS`. If you created a custom user via `new_cache_user.ps1`, use those credentials instead.

### Scraping Tables — Option 1: Windows with Caché running natively

**Problem**: The `InterSystems ODBC` driver is registered within Windows only. The repo is set to run with Linux (due to Make), however running this script via Linux (WSL) is difficult as `InterSystems ODBC` is only accessible from Windows.

**For this reason we run the script via PowerShell using uv.**

Reference: [InterSystems ODBC](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_loadlib)

From PowerShell:

```PowerShell
cd nbss\playcd\poc_backup_restore_pipeline
uv run export_app_tables.py
```

This will save the tables as `.csv` into the folder `cache_data_export/`.

To run the tests:

```PowerShell
uv run -m unittest test_export_app_tables -v
```

### Scraping Tables — Option 2: Mac with Caché running in Parallels

- In Parallels, install Python 32-bit: open PowerShell and run `winget install Python.Python.3.12 --architecture x86`
- Then run `py -3.12-32 -m pip install pyodbc python-dotenv`
- Open File Explorer (in Windows) and find `dtos-breast-nbss-extraction\nbss\playcd\poc_backup_restore_pipeline`. Most likely in 'Home on Mac (Z:/)' drive. Copy the path (for example: `Z:\dtos-breast-nbss-extraction\nbss\playcd\poc_backup_restore_pipeline`).
- Run `cd <path from above>`
- Run `py -3.12-32 export_app_tables.py`

To run the tests:

```PowerShell
py -3.12-32 -m unittest test_export_app_tables -v
```

### Output

The script creates a directory structure under `cache_data_export/`:

```text
cache_data_export/
├── APP/
│   ├── Table1.csv
│   ├── Table2.csv
│   └── ...
├── UTIL/
│   ├── Users.csv
│   └── ...
└── <other schemas>/
```

Example console output:

```output
Connected!

Fetching data from tables

APP.BsoDetails -  1,234 rows x 15 cols → BsoDetails.csv
APP.Clients    - 56,789 rows x 42 cols → Clients.csv
...

All CSVs saved to: C:\...\poc_backup_restore_pipeline\cache_data_export
```

### Files

- `export_app_tables.py` — The main export script (connects via ODBC, exports all tables to CSV)
- `test_export_app_tables.py` — Verifies that the exported CSVs match the database tables (count, completeness, no extras)
- `test_compare_exports.py` — Compares the restored export against the original PlayCD export to verify the backup-restore process did not lose data
- `.env` — Connection credentials (not committed to source control)

### Comparing with the original PlayCD export

`test_compare_exports.py` compares the data scraped from the restored NBSS instance (`poc_backup_restore_pipeline/cache_data_export/`) with the data scraped from the standard PlayCD installation (`data_and_code_export/cache_data_export/`). This identifies whether the backup-restore process missed any data.

> **Prerequisite:** The scrape process on the standard PlayCD install (`data_and_code_export/export_app_tables.py`) must have been completed first for this comparison to be valid.

The test checks:

- Total number of exported CSV files is the same in both directories
- Every CSV in the original has a corresponding CSV in the restored export (and vice versa)
- Row counts match for each table
- Column counts match for each table

#### Running the comparison

```PowerShell
# Option 1: Windows (uv)
uv run -m unittest test_compare_exports -v

# Option 2: Mac via Parallels (32-bit Python)
py -3.12-32 -m unittest test_compare_exports -v
```

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `Access Denied (417)` | Check `UID` and `PWD` in `.env` — the default `_SYSTEM` password for a fresh install is `SYS` |
| `Driver not found` | Open 32-bit ODBC Administrator (`C:\Windows\SysWOW64\odbcad32.exe`) and check the **Drivers** tab for the exact driver name |
| `Connection failed` | Verify the CACHERESTORE instance is running and the `PORT` in `.env` matches (default: `1973`) |
| No tables exported | Check `DATABASE` in `.env` is set to `NBSS` (the namespace created during restore) |

### Note on expected row count differences

When running `test_compare_exports.py`, the APP-schema tables (actual NBSS patient/screening data) should match exactly. However, some `UTIL` tables will show minor row count differences. These are expected and do not indicate data loss:

#### Transient/runtime data (not preserved across restore)

| Table | Explanation |
|-------|-------------|
| `UTIL.CurrentJobs` | Tracks active Caché PIDs at time of scrape. The PlayCD had processes running; the restored instance has none because no NBSS application is active. |
| `UTIL.RemoteAnalysis` | Stored in a global that maps to a system database (e.g. `CACHETEMP` or `mgr\`) which was **not** restored — only `dem_app` and `dem_dat` were. |

#### Data accumulated on the PlayCD *after* the backup was taken

| Table | Explanation |
|-------|-------------|
| `UTIL.SecurityAuditTrail` | The restored data ends at the backup point. Extra entries in the original are from PlayCD usage (logins, password attempts) after the backup was taken. |
| `UTIL.SystemStatus` | Same pattern — the original has Cache startup/shutdown events from PlayCD sessions after the backup. The restored ends at the backup point, plus one new entry from the restore itself. |
| `UTIL.Routine` | Routines compiled on the PlayCD after the backup was taken. |

#### Metadata generated by the restore process itself (slightly more in restored)

| Table | Explanation |
|-------|-------------|
| `UTIL.TableColumns` | Additional column definitions from objects created during restore (namespace, database configuration). |
| `UTIL.TableMethod` | Additional method definitions from the same. |
| `UTIL.TableProperties` | Additional property definitions from the same. |
