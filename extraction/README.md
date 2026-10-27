# NBSS extraction — Back up and upload an NBSS instance

Run these steps on the source BSO machine to create a backup zip of an NBSS instance and upload it to Azure Storage. Follow them in order:

1. [Zip the backup files](#1-zip-the-backup-files)
2. [Transfer the zip file to Azure Storage](#2-transfer-the-zip-file-to-azure-storage)

> [!IMPORTANT]
> Open PowerShell **as Administrator** (right-click PowerShell > **Run as administrator**) before running any of the commands below. Administrator rights are needed to install Azure CLI and AzCopy, and to stop and restart Caché.

## Prerequisites

### Azure resources

- **Azure Storage Account** with a blob container to upload the backup to

### Access & permissions

- **Administrator privileges** on the Windows machine
- A **Microsoft Entra account** with create/write permission on the target storage account
- **Outbound IP whitelisted** on the NHSE Strategic Tenant storage account

### Other

- A **recent NBSS backup** (`BACKUP_CACHE.DAT` or `BACKUP_IRIS.DAT`)
- Enough free disk space in the download folder for the backup zip

## Variables

Gather these values before starting. They are referenced as `<variable_name>` throughout this guide.

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `<bso_code>` | BSO code for the screening unit being backed up | `A0001344` |
| `<storage_account>` | Azure Storage Account name to upload to | `sanbssedevupload` |
| `<container_name>` | Blob container within the storage account | `uploads` |
| `<tenant_id>` | Microsoft Entra tenant ID associated with the storage account (not the subscription ID) | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

## Download the scripts

From an Administrator PowerShell window, `cd` to a folder with enough free disk space, then run:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$base  = "https://raw.githubusercontent.com/NHSDigital/dtos-breast-nbss-extraction/main/extraction"
$dest  = Join-Path (Get-Location) "extraction"
$files = @(
    "create_nbss_back_up.ps1",
    "backup_config.json",
    "install_tools.ps1",
    "tool_versions.json",
    "run_azcopy.ps1"
)
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($f in $files) {
    $out = Join-Path $dest $f
    Invoke-WebRequest -Uri "$base/$f" -OutFile $out -UseBasicParsing
    Unblock-File -Path $out
}
Set-Location $dest
```

`Set-ExecutionPolicy -Scope Process` only applies to the current PowerShell window. If you open a new window, `cd` back to the `extraction` folder and run it again.

This creates an `extraction` folder in the current directory, laid out as follows:

```text
extraction\
├── <YYYYMMDD>-<bso_code>.zip   <- created by step 1
├── create_nbss_back_up.ps1
├── backup_config.json
├── install_tools.ps1
├── tool_versions.json
└── run_azcopy.ps1
```

---

## 1. Zip the backup files

**Run from:** `extraction`

`create_nbss_back_up.ps1` does the following:

1. **Finds the Caché/IRIS instance** under `-CacheRoot` (see `-Instance`), stops it and waits up to 60 seconds for it to shut down
2. **Creates a zip archive** containing the items listed in `backup_config.json` (see [Backup Configuration](#backup-config)). By default:
   - `NBSS\Attachments`, `NBSS\Letters` and `NBSS\Labels` (all contents; any missing folder is skipped)
   - The newest `BACKUP_CACHE.DAT` or `BACKUP_IRIS.DAT` found under `NBSS\Cache` or the selected instance folder, wherever it sits. Audit folders are ignored, and `BACKUP_CACHE_1.DAT` etc. are never picked (exact names only).
3. **Saves the zip** to the `extraction` folder as `{YYYYMMDD}-{BsoCode}.zip`
4. **Restarts the instance**. This happens even if creating the zip fails.

The configuration is checked before the instance is stopped, so an invalid configuration leaves Caché running.

### Parameters

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `-BsoCode` | `A000` | BSO code embedded in the zip filename |
| `-NbssRoot` | `C:\NBSS` | Root folder where NBSS is installed |
| `-CacheRoot` | `C:\InterSystems` | Root folder where InterSystems is installed |
| `-Instance` | *(auto)* | Instance name, which is also its folder under `-CacheRoot` (for example `CACHE` or `CACHE202610V2`). Optional when only one instance is installed. If several are installed the script stops and lists them, so you must supply it. |
| `-ConfigPath` | `backup_config.json` in the script folder | JSON configuration listing what to back up |

### Usage

```powershell
.\create_nbss_back_up.ps1 -BsoCode "<bso_code>"
```

If NBSS or InterSystems are installed on a different drive:

```powershell
.\create_nbss_back_up.ps1 -BsoCode "<bso_code>" -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"
```

If more than one instance is installed under `-CacheRoot`:

```powershell
.\create_nbss_back_up.ps1 -BsoCode "<bso_code>" -Instance "CACHE202610V2"
```

Example output:

```output
[14:30:15] Instance    : CACHE (C:\InterSystems\Cache)
[14:30:15] Root Nbss: C:\NBSS
[14:30:15] Root Cache: C:\InterSystems
[14:30:15] Root Instance: C:\InterSystems\Cache
[14:30:15] Stopping CACHE...
[14:30:20] CACHE stopped.
[14:30:20] Creating zip: C:\path\to\extraction\20260707-A0001344.zip
[14:30:45] Added: C:\NBSS\Attachments
[14:31:00] Added: E:\NBSS\Cache\LIV_DAT\BACKUP_CACHE.DAT
[14:31:05] Backup complete: C:\path\to\extraction\20260707-A0001344.zip (3700.80 MB)
[14:31:10] Restarting CACHE...
[14:31:15] CACHE restarted successfully.
```

### Backup Configuration

`backup_config.json` controls what goes into the zip. Edit it if a machine's layout differs. The default is:

```json
{
  "items": [
    { "root": "Nbss",  "path": "Attachments" },
    { "root": "Nbss",  "path": "Letters" },
    { "root": "Nbss",  "path": "Labels" },
    {
      "latest": true,
      "exclude": ["*audit*"],
      "anyOf": [
        { "root": "Nbss",     "path": "Cache", "find": ["BACKUP_CACHE.DAT", "BACKUP_IRIS.DAT"] },
        { "root": "Instance", "find": ["BACKUP_CACHE.DAT", "BACKUP_IRIS.DAT"] }
      ]
    }
  ]
}
```

| Field | Description |
| ----- | ----------- |
| `root` | Named root the path is relative to. Built in: `Nbss` (`-NbssRoot`), `Cache` (`-CacheRoot`) and `Instance` (the selected instance folder). More can be declared in a top-level `"roots"` object, for example `"roots": { "Restore": "E:\\Cache Restore" }`. |
| `path` | File or folder relative to the root. Folders are added recursively. Wildcards such as `Cache*/mgr` are allowed. |
| `find` | Instead of an exact `path`, one or more exact file names searched for recursively under `root\path` (`path` is optional), wherever they sit. |
| `anyOf` | A list of alternative `{ root, path or find }` locations for one item. Without `latest`, the first alternative that has a match is used. |
| `latest` | When `true`, only the single newest match (by last-modified time) across all alternatives is added. |
| `exclude` | Wildcard patterns matched against the full file path. Matching files are ignored. |

A missing item is logged and skipped.

### Notes

- Caché will be unavailable while the zip is being created (usually a few minutes, depending on database size).
- `LIV_APP` and `MEDIFACT` also contain `BACKUP_CACHE.DAT` or `BACKUP_IRIS.DAT` files. Because the default configuration picks the single newest match, it could select one of those instead of `LIV_DAT`. Narrow the `path` (for example `Cache/LIV_DAT`) if you only want the live data backup.
- If a zip with the same name already exists, the script fails, so delete or rename the existing zip first. The instance is still restarted.
- If the instance cannot be restarted, the script ends with an error. Start it manually.

---

## 2. Transfer the zip file to Azure Storage

**Run from:** `extraction`

### Install Azure CLI and AzCopy

```powershell
.\install_tools.ps1
```

`install_tools.ps1` installs the versions pinned in `tool_versions.json`:

- **Azure CLI**: downloads the MSI to `%TEMP%` and installs it silently
- **AzCopy**: downloads the zip to `%TEMP%`, installs `azcopy.exe` to `C:\Program Files\AzCopy` and adds that folder to the machine `PATH`

The script checks that each download carries a valid Microsoft code signature before installing it. A tool that is already on `PATH` is left as it is. If `az` or `azcopy` can't be found afterwards, open a new PowerShell window (as Administrator).

To install AzCopy somewhere else, pass `-AzCopyInstallDir`:

```powershell
.\install_tools.ps1 -AzCopyInstallDir "D:\tools\AzCopy"
```

### Upload the zip

```powershell
.\run_azcopy.ps1 -LocalFilePath "<target_zip_path>" -TenantId "<tenant_id>" -SubscriptionId "<subscription_id>" -StorageAccountName "<storage_account>" -ContainerName "<container_name>"
```

`run_azcopy.ps1` does the following:

1. Signs in to Azure CLI (`az login --tenant <tenant_id>`). A browser window opens for you to sign in with your Microsoft Entra account. The interactive subscription picker is disabled.
2. Selects the subscription (`az account set --subscription <subscription_id>`)
3. Signs in to AzCopy using those Azure CLI credentials (`azcopy login --login-type azcli`)
4. Uploads the zip as a block blob to `https://<storage_account>.blob.core.windows.net/<container_name>` with an MD5 hash (`--put-md5`). The upload role can only create new blobs, so an existing blob with the same name is **not** overwritten and the upload fails with a 403.

The script stops if sign-in, subscription selection or the upload fails.

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `-LocalFilePath` | *(none)* | Path to the zip created in step 1 |
| `-TenantId` | *(none)* | Microsoft Entra tenant ID. Always supply this. |
| `-SubscriptionId` | *(none)* | Azure subscription ID to use after sign-in. Always supply this. |
| `-StorageAccountName` | `sanbssedevupload` | Target storage account |
| `-ContainerName` | `uploads` | Target blob container |

---

## Quickstart

Run from an Administrator PowerShell window after [downloading the scripts](#download-the-scripts). Start in the `extraction` folder:

```powershell
# 1. Zip the backup files
.\create_nbss_back_up.ps1 -BsoCode "<bso_code>"

# 2. Install tools (first time only) and upload
.\install_tools.ps1
.\run_azcopy.ps1 -LocalFilePath ".\<YYYYMMDD>-<bso_code>.zip" -TenantId "<tenant_id>" -SubscriptionId "<subscription_id>" -StorageAccountName "<storage_account>" -ContainerName "<container_name>"
```
