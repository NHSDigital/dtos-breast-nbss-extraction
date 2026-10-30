# NBSS extraction — Back up and upload an NBSS instance

Run these steps on the source BSO machine to create a backup zip of an NBSS instance and upload it to Azure Storage. Follow them in order:

1. [Zip the backup files](#1-zip-the-backup-files)
2. [Transfer the zip file to Azure Storage](#2-transfer-the-zip-file-to-azure-storage)

> [!IMPORTANT]
> Open PowerShell **as Administrator** (right-click PowerShell > **Run as administrator**) before running any of the commands below. Administrator rights are needed to install Azure CLI and AzCopy.

## Prerequisites

### Azure resources

- **Azure Storage Account** with a blob container to upload the backup to

### Access & permissions

- **Administrator privileges** on the Windows machine
- A **Microsoft Entra account** with create/write permission on the target storage account
- **Outbound IP whitelisted** on the NHSE Strategic Tenant storage account

### Other

- An **NBSS backup** (`BACKUP*.DAT`, for example `BACKUP_CACHE.DAT` or `BACKUP_IRIS.DAT`) in `NBSS\Cache\LIV_DAT` that is less than 7 days old
- Enough free disk space in the download folder for the backup zip (up to 50 GB)

## Variables

Gather these values before starting. They are referenced as `<variable_name>` throughout this guide.

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `<bso_name>` | Name of the screening unit being backed up | `West of London` |
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
    "create_nbss_zip.ps1",
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
├── <YYYY-MM-DD>-<bso_name>-<bso_code>.zip   <- created by step 1
├── create_nbss_zip.ps1
├── install_tools.ps1
├── tool_versions.json
└── run_azcopy.ps1
```

---

## 1. Zip the backup files

**Run from:** `extraction`

`create_nbss_zip.ps1` zips existing files only. It doesn't stop Caché or take a new backup. It does the following:

1. **Finds backup files**: the newest `BACKUP*.DAT` in each folder under `<NbssDrive>:\NBSS` and `<InterSystemsDrive>:\InterSystems`. For example, if `LIV_DAT` has both `BACKUP_CACHE.DAT` and `BACKUP_CACHE_1.DAT`, only the most recently modified one is zipped.
2. **Checks the live data backup**: stops with an error if there's no `BACKUP*.DAT` directly in `<NbssDrive>:\NBSS\Cache\LIV_DAT` (subfolders such as `LIV_DAT\archive` don't count), or if the newest one is more than 7 days old
3. **Finds NBSS files**: everything in `NBSS\Attachments`, `NBSS\Letters`, `NBSS\Labels` and `NBSS\Reports`. A missing folder is skipped with a warning.
4. **Creates the zip** in the `extraction` folder as `<YYYY-MM-DD>-<bso_name>-<bso_code>.zip`. Paths inside the zip match the paths on disk without each file's drive letter, for example `NBSS/Attachments/...` and `NBSS/Cache/LIV_DAT/BACKUP_CACHE.DAT`. The zip also contains `manifest.csv` at its root, listing each file's `Path`, `SizeBytes` and `LastWriteTimeUtc` (ISO 8601), so the newest backup can be identified at restore time.
5. **Checks the zip size**: if the zip is 50 GB or more, it's deleted and the script stops with an error

### Parameters

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `-BsoName` | *(required)* | BSO name for the zip filename. Spaces and any characters other than letters, digits and `-` are replaced with `_`. |
| `-BsoCode` | *(required)* | BSO code for the zip filename. Letters and digits only. |
| `-NbssDrive` | `C` | Drive letter where the `NBSS` folder is |
| `-InterSystemsDrive` | `C` | Drive letter where the `InterSystems` folder is |

### Usage

```powershell
.\create_nbss_zip.ps1 -BsoName "<bso_name>" -BsoCode "<bso_code>"
```

If NBSS and InterSystems are on other drives, for example `D:\NBSS` and `E:\InterSystems`:

```powershell
.\create_nbss_zip.ps1 -BsoName "<bso_name>" -BsoCode "<bso_code>" -NbssDrive "D" -InterSystemsDrive "E"
```

Example output:

```output
Searching for BACKUP*.DAT files in C:\NBSS and C:\InterSystems ...
   C:\NBSS\Cache\LIV_APP\BACKUP_CACHE.DAT (27/10/2026 02:00:12)
   C:\NBSS\Cache\LIV_DAT\BACKUP_CACHE.DAT (27/10/2026 02:05:40)
Found 1520 file(s) in C:\NBSS\Attachments.
Found 310 file(s) in C:\NBSS\Letters.
Found 42 file(s) in C:\NBSS\Labels.
WARNING: Folder not found, skipping: C:\NBSS\Reports
Creating C:\path\to\extraction\2026-10-29-West_of_London-A0001344.zip ...
Created C:\path\to\extraction\2026-10-29-West_of_London-A0001344.zip (3.61 GB, 1874 files).
```

### Notes

- If a zip with the same name already exists, the script fails. Delete or rename the existing zip first.
- If the script fails while creating the zip, the incomplete zip is deleted.

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
.\create_nbss_zip.ps1 -BsoName "<bso_name>" -BsoCode "<bso_code>"

# 2. Install tools (first time only) and upload
.\install_tools.ps1
.\run_azcopy.ps1 -LocalFilePath ".\<YYYY-MM-DD>-<bso_name>-<bso_code>.zip" -TenantId "<tenant_id>" -SubscriptionId "<subscription_id>" -StorageAccountName "<storage_account>" -ContainerName "<container_name>"
```
