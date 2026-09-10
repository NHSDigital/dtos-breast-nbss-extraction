# BSO process — Back up and upload an NBSS instance

This is the **first half** of the NBSS backup-restore proof of concept. It is run
on (or against) the source BSO machine to produce a verified backup zip and push
it to Azure. The steps should be followed sequentially:

- **Step 2** — [Create zip file containing the required backup files](2_zip_backup_files/README.md)
- **Step 3** — [Hash the zip and store the hash in Azure Key Vault](3_hash_and_store/README.md)
- **Step 4** — [Transfer the zip file to Azure Storage](4_transfer_to_storage/README.md)

> Step 1 — [Backup NBSS manually](../1_manual_nbss_backup/README.md) — is optional
> and only required if a scheduled overnight backup is not available. It lives
> outside this folder because it is a shared, optional pre-step.

Once the zip is in Azure Storage, continue with the
[NBSSE process](../nbsse_process/README.md) to download, restore and scrape it.

Details of each step are set out in the linked READMEs.

## Prerequisites

### Azure resources

- **Azure Storage Account** with a blob container for backup storage
- **Azure Key Vault** for storing backup file hashes

### Software

- **Azure CLI** — <https://aka.ms/installazurecliwindows>
- **AzCopy v10** — <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>

### Access & permissions

- **Administrator privileges** on the Windows machine (step 2 stops/starts the Caché service)
- **Azure CLI authentication** (`az login`) with a Microsoft Entra account that has:
  - **Key Vault Secrets Officer** on the target Key Vault (to store hashes)
  - **Storage Account key access** or **Storage Blob Data Contributor** (for SAS token generation and blob upload)

### Other

- A **recent NBSS backup** — either the scheduled overnight backup or a manual one taken via the [optional step 1](../1_manual_nbss_backup/README.md)

## Variables

Gather these values before starting. They are referenced as `<variable_name>` throughout the quickstart below.

| Variable | Description | Example |
|----------|-------------|---------|
| `<bso_code>` | BSO code for the screening unit being backed up | `A0001344` |
| `<storage_account>` | Azure Storage Account name for backup storage | `bsrtestdatalake` |
| `<container_name>` | Blob container within the storage account | `bso-001-container` |
| `<key_vault_name>` | Azure Key Vault name for storing backup hashes | `nbsse-dev-kv` |

## Install AzCopy on Windows

- Open the [AzCopy download page](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10) and download the latest **Windows 64-bit** ZIP file.
- Extract the ZIP file and copy the folder containing `azcopy.exe` to `C:\azcopy`.
- Open PowerShell and add `C:\azcopy` to the User PATH:

```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains 'C:\azcopy') {
 [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\azcopy", "User")
}
```

Alternatively, add the folder manually through the Windows settings. Open the Windows Start menu and search for **Edit environment variables for your account**. Select **Environment Variables...**. In **User variables for [your username]**, select `Path` and choose **Edit**. Select **New**, enter `C:\azcopy`, and select **OK** on each open dialog.

- Close and reopen PowerShell or VS Code so that the updated PATH is loaded.
- Verify that AzCopy is available:

```powershell
Get-Command azcopy
azcopy --version
```

The User PATH makes AzCopy available to the Windows account that installed it. Administrator permissions are not required unless the user cannot create the `C:\azcopy` folder.

## Related docs

- [Create a storage container in an existing storage account](../docs/generate_storage_container.md)
- [Azure Key Vault — create, retrieve and set RBAC for secrets](../docs/azure_key_vault.md)

---

## Quickstart

Simplest path through the BSO process. All commands run from the relevant step sub-folder. The zip is created in and read from `bso_process`.

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

## A note on naming convention

A consistent naming pattern is used across all steps to ensure the hash stored in Key Vault can be matched to the correct blob in storage. The pattern is:

| Artifact | Format | Example |
|----------|--------|---------|
| Zip filename (uploaded to storage) | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |
| Key Vault secret name | `{YYYYMMDD}-{BsoCode}-hash` | `20260715-A0001344-hash` |
| Blob name in storage container | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |

The NBSSE download script (step 5) derives the secret name by stripping the `.zip` extension from the blob name and appending `-hash`.
