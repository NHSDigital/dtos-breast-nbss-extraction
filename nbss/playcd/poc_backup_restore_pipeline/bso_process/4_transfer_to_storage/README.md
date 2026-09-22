# 4. Transfer the zip file to Azure Storage

You need to have Azure CLI installed and be logged in on your Microsoft Entra account to access the storage account.

## Requirements

- **AzCopy** — Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>, or install and add it to the PATH by running:

```powershell
.\install_azcopy.bat
```

- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>

## Usage

Run the below AzCopy command:

```PowerShell
azcopy copy "<local path to file to upload>" "https://<storageaccount name>.blob.core.windows.net/<storagecontainer name>"
```

Once run, if successful, you should see the command return that it has done a write operation to the storage container.
