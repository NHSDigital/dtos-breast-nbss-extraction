## 4. Transfer the zip file to Azure Storage

Reference: [SAS token generation](../../sas_service_token_script/sas-token-generation.md)
You need to have Azure CLI installed and be logged in on your Microsoft Entra account to access the account keys for the storage account.

### Requirements

- **AzCopy** — Install from <https://learn.microsoft.com/en-us/azure/storage/common/storage-use-AzCopy-v10>
- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>

### Usage

Run the shell script interactively to be prompted to input the storage account name and container name.

| Variable | Value | Description |
|-----------|---------|-------------|
| `-storage_account` | `bsrtestdatalake` | Storage account to copy the file to |
| `-container_name` | `bso-001-container` | Name of the container we are copying to |
| `-local path to file to upload` | *(newest `*.zip` in script folder)* | Full path to the hashed zip file |

```shell
bash generate-container-sas-token.sh
```

Run the shell script non-interactively by providing parameters:

```shell
bash generate-container-sas-token.sh <storage_account> <container_name>
```

Once the command is run, if you have the correct permissions and the right account/container names, the command will return a raw string which is the SAS token. Copy this token to use in the AzCopy operation.

Fill the command with the relevant info and append the SAS token to the end. The easiest way to upload the file is to run the AzCopy command from the same directory as the file and just specify the file name in the local path to file section.

```shell
AzCopy copy "<local path to file to upload>" "https://<storageaccount name>.blob.core.windows.net/<storagecontainer name>?<sas token>"
```

Once run, if successful, you should see the command return that it has done a write operation to the storage container.
