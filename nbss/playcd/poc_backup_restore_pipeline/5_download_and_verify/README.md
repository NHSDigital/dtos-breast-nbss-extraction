## 5. Retrieve the file from storage and verify integrity

### Overview

The `download_latest_blob.ps1` PowerShell script downloads the most recently modified blob from an Azure Storage Account container, computes its SHA-256 hash, and compares it against the hash stored in Azure Key Vault to verify the file has not been tampered with or corrupted during transfer.

1. **Downloads the latest blob** — Lists all blobs in the specified container, identifies the most recently modified, and downloads it to `poc_backup_restore_pipeline`
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

The `.bat` wrapper (`download_latest_blob.bat`) bypasses PowerShell execution policy restrictions — the same reason as `create_nbss_back_up.bat`. See [Why Run Through the .bat File?](../2_zip_backup_files/README.md#why-run-through-the-bat-file) in step 2.

### Usage

From `nbss/playcd/poc_backup_restore_pipeline/5_download_and_verify`:

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

- The file is downloaded to `poc_backup_restore_pipeline`
- The secret name is derived from the blob filename: `{filename-without-extension}-hash` e.g. blob `20260715-A0001344.zip` → secret `20260715-A0001344-hash`
- If the container has multiple blobs, the most recently modified one is selected
- A hash mismatch indicates the file may have been corrupted or tampered with — do not proceed with the restore
