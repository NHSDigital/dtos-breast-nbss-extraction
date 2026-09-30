# 4. Transfer the zip file to Azure Storage

The upload script signs in to Azure CLI with your Microsoft Entra account, then uses those credentials with AzCopy to upload the zip file. The account needs the **Storage Blob Data Contributor** role (or **Storage Blob Data Owner**) on the target storage account or container.

## Requirements

- **AzCopy** — Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>

- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>

or install both tools by running this script which uses winget to add the tools to your environment:

```powershell
.\install_tools.bat
```

## Usage

From this directory, run the script with the zip created in `bso_process`. Use the Microsoft Entra tenant ID associated with the storage account, not the subscription ID:

```powershell
.\run_azcopy.ps1 -LocalFilePath "..\<YYYYMMDD>-<bso_code>.zip" -TenantId "<tenant_id>" -StorageAccountName "<storage_account>" -ContainerName "<container_name>"
```

`-StorageAccountName` defaults to `sanbssedevupload` and `-ContainerName` defaults to `uploads` if omitted. Supply `-TenantId` explicitly: the script uses it for both `az login` and `azcopy login --login-type azcli`. The upload overwrites an existing blob with the same name and sets its Content-MD5 property. The script stops if either login or the upload fails.
