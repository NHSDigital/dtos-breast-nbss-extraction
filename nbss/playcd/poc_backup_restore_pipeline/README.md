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

## 3. Hash zip and store in Azure Key Vault

### Overview

The `transfer_hash_zip.ps1` PowerShell script computes a SHA-256 hash of the backup zip file and stores it as a secret in Azure Key Vault. This allows the integrity of the backup to be verified at any point — if the hash stored in Key Vault matches the hash of the file you download, the file has not been tampered with or corrupted. Once complete, follow the [AzCopy](#step-2---azcopy-to-storage) steps to copy the hashed zip file to the storage account.

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
- **A zip file** — Produced by `create_nbss_back_up.bat` in the previous step**
- **AzCopy** - Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>

### Step 1 - Hash and Store

The script will compute a SHA-256 hash of the zip file and then store the hash value as a secret in Azure Key Vault, allowing the integrity of the backup to be verified later.

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BsoCode` | *(mandatory)* | BSO code embedded in the secret name e.g. `A0001344` |
| `-KeyVaultName` | `nbsse-dev-kv` | Name of the Azure Key Vault |
| `-ZipPath` | *(newest `*.zip` in script folder)* | Full path to the zip file to hash |

#### Usage

From `nbss/playcd/poc_backup_restore_pipeline`:

##### Simple (auto-detects newest zip)

```PowerShell
.\transfer_hash_zip.bat A0001344
```

##### With explicit zip path

```PowerShell
.\transfer_hash_zip.bat A0001344 "C:\path\to\NBSS_A0001344_Backup_20260715_143015.zip"
```

##### With a different Key Vault

```PowerShell
.\transfer_hash_zip.ps1 -BsoCode "A0001344" -KeyVaultName "my-other-kv" -ZipPath "C:\path\to\backup.zip"
```

#### Output

```output
Zip file   : C:\...\NBSS_A0001344_Backup_20260715_143015.zip
SHA-256    : ....
Secret name: 20260715-A0001344-hash
Azure CLI  : logged in as user@nhs.net
Storing secret in Key Vault 'nbsse-dev-kv' ...
Secret stored successfully.
Secret ID  : https://nbsse-dev-kv.vault.azure.net/secrets/20260715-A0001344-hash/...
```

#### Files

- `transfer_hash_zip.ps1` — The main PowerShell script (hashing and Key Vault logic)
- `transfer_hash_zip.bat` — Wrapper batch file (enables running without execution policy issues)

### Step 2 - AzCopy to Storage

Reference: [SAS token generation](../sas_service_token_script/sas-token-generation.md)
You need to have Azure CLI installed and be logged in on your Microsoft Entra account to access the account keys for the storage account.

#### Execution

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

### Notes

- Key Vault secret names only allow **letters, numbers, and hyphens** — underscores are not permitted
- Running the script on the same day with the same BSO code will **overwrite** the existing secret for that day. Use `-ZipPath` explicitly if running multiple times per day to ensure the correct file is hashed
- The script will prompt for `az login` automatically if you are not already authenticated

## 4. Retrieve the file from storage and verify integrity

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

### Usage

From `nbss/playcd/poc_backup_restore_pipeline`:

#### Simple (default Key Vault)

```PowerShell
.\download_latest_blob.ps1 -ContainerName "bso-001-container" -StorageAccountName "bsrtestdatalake"
```

#### With a different Key Vault

```PowerShell
.\download_latest_blob.ps1 -ContainerName "bso-001-container" -StorageAccountName "bsrtestdatalake" -KeyVaultName "my-other-kv"
```

### Output

```output
Latest blob: 20260715-A0001344.zip
Download complete: C:\...\poc_backup_restore_pipeline\20260715-A0001344.zip
SHA-256    : E6129C1AA9F62945DC64E3E920A028FC545427E2CCB999606D58FA32E4E70F1A
Secret name: 20260715-A0001344-hash
Stored hash: E6129C1AA9F62945DC64E3E920A028FC545427E2CCB999606D58FA32E4E70F1A
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

### Notes

- The file is downloaded to the same directory as the script
- The secret name is derived from the blob filename: `{filename-without-extension}-hash` e.g. blob `20260715-A0001344.zip` → secret `20260715-A0001344-hash`
- If the container has multiple blobs, the most recently modified one is selected
- A hash mismatch indicates the file may have been corrupted or tampered with — do not proceed with the restore

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
