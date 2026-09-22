# 4. Retrieve the file from storage

## Overview

The `download_latest_blob.ps1` PowerShell script downloads the most recently modified blob from an Azure Storage Account container.

1. **Downloads the latest blob** — Lists all blobs in the specified container, identifies the most recently modified, and downloads it to `nbsse_process`

## Requirements

- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>
- **Azure login** — Run `az login` before executing the script
- **Storage Account access** — The authenticated identity must have read access to the storage container

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ContainerName` | *(mandatory)* | Name of the Azure Storage container |
| `-StorageAccountName` | *(mandatory)* | Name of the Azure Storage Account |

## Why Run Through the .bat File?

The `.bat` wrapper (`download_latest_blob.bat`) bypasses PowerShell execution policy restrictions — the same reason as `create_nbss_back_up.bat`. See [Why Run Through the .bat File?](../../bso_process/2_zip_backup_files/README.md#why-run-through-the-bat-file) in step 2.

## Usage

From `nbss/playcd/poc_backup_restore_pipeline/nbsse_process/4_download_and_verify`:

### Download the latest blob

```PowerShell
.\download_latest_blob.bat bso-001-container bsrtestdatalake
```

### Running the PowerShell script directly

```PowerShell
.\download_latest_blob.ps1 -ContainerName "bso-001-container" -StorageAccountName "bsrtestdatalake"
```

## Output

```output
Latest blob: 20260715-A0001344.zip
Download complete: C:\...\poc_backup_restore_pipeline\nbsse_process\20260715-A0001344.zip
```

## Files

- `download_latest_blob.ps1` — The main PowerShell script
- `download_latest_blob.bat` — Wrapper batch file (enables running without execution policy issues)

## Notes

- The file is downloaded to `nbsse_process`
- If the container has multiple blobs, the most recently modified one is selected
