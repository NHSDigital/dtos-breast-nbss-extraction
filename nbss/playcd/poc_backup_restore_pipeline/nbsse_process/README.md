# NBSSE process — Download, restore and scrape an NBSS backup

This is the **second half** of the NBSS backup-restore proof of concept. It is run
on a clean restore-target machine to pull the backup zip from Azure, restore it
onto a fresh Caché installation, verify it, and scrape the tables into Databricks.
It follows on from the [BSO process](../bso_process/README.md), which produces and
uploads the backup zip. The steps should be followed sequentially:

- **Step 5** — [Retrieve the file from storage and verify integrity](5_download_and_verify/README.md)
- **Step 6** — [Set up a clean Caché DB](6_setup_clean_cache/README.md)
- **Step 7** — [Restore the backup onto a clean Caché installation](7_restore_backup/README.md)
- **Step 8** — [Verify database integrity](8_verify_integrity/README.md)
- **Step 9** — [Scrape the tables from Caché to Databricks](9_scrape_tables/README.md)

Details of each step are set out in the linked READMEs.

## Prerequisites

### Azure resources

- **Azure Storage Account** with the blob container the backup was uploaded to (by the BSO process)
- **Azure Key Vault** holding the backup file hash (used to verify the download in step 5)

### Databricks resources

- **Databricks workspace** with a Unity Catalog catalog and schema to write the exported tables to (step 9)
- **A running SQL warehouse** in that workspace (its HTTP path is needed for the `.env` file in step 9)

### Software

- **Azure CLI** — <https://aka.ms/installazurecliwindows> (step 5)
- **Databricks CLI** — <https://docs.databricks.com/en/dev-tools/cli/install.html> (authenticated, for step 9)
- **InterSystems Caché PlayCD installer zip** 2018.1.4.505.1
- **Python 3.12** with `uv` (Windows) or 32-bit Python (Mac via Parallels)

### Access & permissions

- **Administrator privileges** on the Windows machine (to stop/start Caché services)
- **Azure CLI authentication** (`az login`) with a Microsoft Entra account that has:
  - **Key Vault Secrets User** on the target Key Vault (to retrieve hashes)
  - **Storage Account key access** or **Storage Blob Data Contributor** (for blob download)
- **Databricks CLI authentication** with permission to create schemas and tables in the target Unity Catalog catalog and to use the SQL warehouse (for step 9)

### Other

- **TCP ports 1973 and 57773 available** (for the CACHERESTORE Caché instance)
- **No NBSS/Caché installation** on the restore target machine (remove `C:\NBSS\` and `C:\InterSystems\` too if applicable)

## Variables

Gather these values before starting. They are referenced as `<variable_name>` throughout the quickstart below.

| Variable | Description | Example |
|----------|-------------|---------|
| `<bso_code>` | BSO code for the screening unit being restored | `A0001344` |
| `<storage_account>` | Azure Storage Account name for backup storage | `bsrtestdatalake` |
| `<container_name>` | Blob container within the storage account | `bso-001-container` |
| `<key_vault_name>` | Azure Key Vault name holding the backup hash | `nbsse-dev-kv` |
| `<play_cd_zip>` | Path to the PlayCD zip containing the Caché installer | `C:\Temp\PlayCD.zip` |
| `<cache_password>` | Password for the CACHERESTORE Caché instance (`SYS` for a fresh install) | `SYS` |

## Related docs

- [Azure Key Vault — create, retrieve and set RBAC for secrets](../docs/azure_key_vault.md)
- [Creating a Caché user](../docs/create_admin_user.md)

---

## Quickstart

Simplest path through the NBSSE process. All commands run from the relevant step sub-folder. The zip is downloaded into `nbsse_process`.

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
.\restore_nbss_back_up.bat -BackupZip "..\<YYYYMMDD>-<bso_code>.zip"
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

### 9. Export tables to Databricks

Create `.env` in this folder (`nbsse_process`):

```text
DRIVER=InterSystems ODBC
SERVER=localhost
PORT=1973
DATABASE=NBSS
UID=_SYSTEM
PWD=<cache_password>
DATABRICKS_PROFILE=dev
DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/<your-warehouse-id>
CATALOG = <catalog>
SCHEMA = <schema>
```

Then, from `9_scrape_tables`:

```Python
uv run export_app_tables.py
```

This connects to Caché via ODBC and writes every base table directly to the Databricks Unity Catalog (`<catalog>.<schema>`) as managed Delta tables, named `<source_schema>_<table>` in lowercase.

To verify the export matches the source tables:

```Python
uv run -m unittest test_export_app_tables -v
```

## A note on naming convention

The BSO process names artifacts so the hash stored in Key Vault can be matched to
the correct blob in storage:

| Artifact | Format | Example |
|----------|--------|---------|
| Zip filename (uploaded to storage) | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |
| Key Vault secret name | `{YYYYMMDD}-{BsoCode}-hash` | `20260715-A0001344-hash` |
| Blob name in storage container | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |

The download script (step 5) derives the secret name by stripping the `.zip` extension from the blob name and appending `-hash`.
