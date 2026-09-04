# 4. Transfer the zip file to Azure Storage

Reference: [SAS token generation](./generate-container-sas-token.ps1)
You need to have Azure CLI installed and be logged in on your Microsoft Entra account to access the account keys for the storage account.

## Requirements

- **AzCopy** — Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>
- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>

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
