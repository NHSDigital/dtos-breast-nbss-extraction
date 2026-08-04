# NBSS Backup-Restore process - Proof of Concept

This documentation and code details the steps required to backup and restore an NBSS instance. The steps should be followed sequentially as follows

## Table of contents

1. [Backup NBSS manually](1_manual_nbss_backup/README.md) (optional: only if scheduled overnight backup not available)
2. [Create zip file containing the required backup files](2_zip_backup_files/README.md)
3. [Hash the zip and store the hash in Azure Key Vault](3_hash_and_store/README.md)
4. [Transfer the zip file to Azure Storage](4_transfer_to_storage/README.md)
5. [Retrieve the file from storage and verify integrity](5_download_and_verify/README.md)
6. [Set up a clean Caché DB](6_setup_clean_cache/README.md)
7. [Restore the backup onto a clean Caché installation](7_restore_backup/README.md)
8. [Verify database integrity](8_verify_integrity/README.md)
9. [Scrape the tables from Caché to CSV](9_scrape_tables/README.md)

Details of each of the steps are set out in the linked READMEs.

## Prerequisites

### Azure resources

- **Azure Storage Account** with a blob container for backup storage
- **Azure Key Vault** for storing and retrieving backup file hashes

### Software

- **Azure CLI** — <https://aka.ms/installazurecliwindows>
- **AzCopy v10** — <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>
- **InterSystems Caché PlayCD installer zip** 2018.1.4.505.1
- **Python 3.12** with `uv` (Windows) or 32-bit Python (Mac via Parallels)

**Note, once AzCopy is downloaded, extract and add the executable file (`azcopy.exe`) to `poc_backup_restore_pipeline/4_transfer_to_storage`, this is required to run step 4.**

### Access & permissions

- **Administrator privileges** on the Windows machine (to stop/start Caché services)
- **Azure CLI authentication** (`az login`) with a Microsoft Entra account that has:
  - **Key Vault Secrets Officer** on the target Key Vault (to store hashes)
  - **Key Vault Secrets User** on the target Key Vault (to retrieve hashes)
  - **Storage Account key access** or **Storage Blob Data Contributor** (for SAS token generation and blob upload/download)

### Other

- **TCP ports 1973 and 57773 available** (for the CACHERESTORE Caché instance)
- **No NBSS/Caché installation** on the restore target machine (remove `C:\NBSS\` and `C:\InterSystems\` too if applicable)

## Variables

Gather these values before starting. They are referenced as `<variable_name>` throughout the quickstart below.

| Variable | Description | Example |
|----------|-------------|---------|
| `<bso_code>` | BSO code for the screening unit being backed up | `A0001344` |
| `<storage_account>` | Azure Storage Account name for backup storage | `bsrtestdatalake` |
| `<container_name>` | Blob container within the storage account | `bso-001-container` |
| `<key_vault_name>` | Azure Key Vault name for storing backup hashes | `nbsse-dev-kv` |
| `<play_cd_zip>` | Path to the PlayCD zip containing the Caché installer | `C:\Temp\PlayCD.zip` |
| `<cache_password>` | Password for the CACHERESTORE Caché instance (`SYS` for a fresh install) | `SYS` |

---

## Quickstart

Simplest path through the pipeline. All commands run from the relevant step sub-folder.

### 1. Backup NBSS (skip if overnight backup is recent)

In Caché Terminal:

```ObjectScript
ZN "%SYS"
DO ^BACKUP
```

Select `1` (Backup) → `1` (Full) → type `BACKUP_CACHE.DAT` → `enter` no description → `y` to start. After backup is complete type `HALT`.

### 2. Zip the backup files

```Powershell
.\create_nbss_back_up.bat -BsoCode "<bso_code>"
```

### 3. Hash and store in Key Vault

Login to Azure if you aren't already in this session:

```Powershell
az login
```

```Powershell
.\transfer_hash_zip.bat <bso_code>
```

### 4. Upload to Azure Storage

Login to Azure if you aren't already in this session:

```Powershell
az login
```

```Powershell
.\generate-container-sas-token.bat <storage_account> <container_name>
```

Copy the returned SAS token and run:

```Powershell
./azcopy copy "../<YYYYMMDD>-<bso_code>.zip" "https://<storage_account>.blob.core.windows.net/<container_name>?<sas-token>"
```

### 5. Download and verify integrity

Login to Azure if you aren't already in this session:

```Powershell
az login
```

```Powershell
.\download_latest_blob.bat <container_name> <storage_account>
```

Confirms hash matches Key Vault. Do not proceed if there is a mismatch.

### 6. Install clean Caché

Extract the PlayCD installer:

```powershell
Expand-Archive "<play_cd_zip>" -DestinationPath "C:\Temp\CacheInstaller"
```

The installer will be at `C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe`.

then:

```Powershell
.\install_cache_silent.bat -InstallerPath "C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe"
```

### 7. Restore the backup

```Powershell
.\restore_nbss_back_up.bat -BackupZip ".\<YYYYMMDD>-<bso_code>.zip"
```

When the interactive `^DBREST` terminal opens, respond:

| Prompt | Response |
|--------|----------|
| `1 =>` | `2` |
| `Do you want to set switch 10...?` | Enter |
| `Device:` | `C:\InterSystems\CacheRestore\mgr\BACKUP_CACHE.DAT` |
| `Is this the backup you want to start restoring?` | Enter |
| `c:\intersystems\cache\mgr\` | `X` |
| `c:\intersystems\cache\mgr\cacheaudit\` | `X` |
| `c:\intersystems\cache\mgr\user\` | `X` |
| `c:\nbss\cache\dem_app\` | `C:\NBSS\Cache\dem_app\` |
| `c:\nbss\cache\dem_dat\` | `C:\NBSS\Cache\dem_dat\` |
| `Do you want to change this list?` | Enter |
| `Confirm Restore?` | `Yes` |
| `Device:` (next volume) | `STOP` |
| `Do you have any more backups to restore?` | `No` |
| `Apply: 1 =>` | `4` |

Type `HALT` to exit. The script continues automatically.

### 8. Verify integrity

```Powershell
.\run_integrity_check.bat
```

Exit code `0` = passed.

### 9. Export tables to CSV

Create `.env` in this folder `9_scrape_tables`:

```text
DRIVER=InterSystems ODBC
SERVER=localhost
PORT=1973
DATABASE=NBSS
UID=_SYSTEM
PWD=<cache_password>
```

Then:

```Powershell
uv run export_app_tables.py
```

Output lands in `exported_nbss_data/`.

## A note on naming convention

A consistent naming pattern is used across all steps to ensure the hash stored in Key Vault can be matched to the correct blob in storage. The pattern is:

| Artifact | Format | Example |
|----------|--------|---------|
| Zip filename (uploaded to storage) | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |
| Key Vault secret name | `{YYYYMMDD}-{BsoCode}-hash` | `20260715-A0001344-hash` |
| Blob name in storage container | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |

The download script (step 4) derives the secret name by stripping the `.zip` extension from the blob name and appending `-hash`.
