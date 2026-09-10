# 4. Transfer the zip file to Azure Storage

Reference: [SAS token generation](./generate-container-sas-token.ps1)
You need to have Azure CLI installed and be logged in on your Microsoft Entra account to access the account keys for the storage account.

## Requirements

- **AzCopy** — Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>. To add AzCopy to your PATH, follow the [instructions](../README.md#install-azcopy-on-windows).
- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>

## Usage

Run the script interactively to be prompted to input the storage account name and container name.

| Parameter | Value | Description |
|-----------|---------|-------------|
| `-StorageAccount` | `bsrtestdatalake` | Storage account to copy the file to |
| `-ContainerName` | `bso-001-container` | Name of the container we are copying to |
| `local path to file to upload` | *(newest `*.zip` in script folder)* | Full path to the hashed zip file |

```powershell
.\generate-container-sas-token.bat
```

Run the script non-interactively by providing parameters:

```powershell
.\generate-container-sas-token.bat -StorageAccount "<storage_account>" -ContainerName "<container_name>"
```

Once the command is run, if you have the correct permissions and the right account/container names, the command will return a raw string which is the SAS token. Copy this token to use in the AzCopy operation.

Fill the command with the relevant info and append the SAS token to the end. The easiest way to upload the file is to run the AzCopy command from the same directory as the file and just specify the file name in the local path to file section.

```PowerShell
azcopy copy "<local path to file to upload>" "https://<storageaccount name>.blob.core.windows.net/<storagecontainer name>?<sas token>"
```

Once run, if successful, you should see the command return that it has done a write operation to the storage container.
