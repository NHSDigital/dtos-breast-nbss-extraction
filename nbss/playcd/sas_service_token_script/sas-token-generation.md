### Service SAS token generation

This read me section describes what the generate-container-sas-token.sh script does and how to run it.
The main purpose of this script is to generate a [service SAS](https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas) with write permissions only.
This can then be used in a [az copy command](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs-upload) to authenticate the user and upload the file to a storage container.

## Prerequisites

You need to have azure CLI installed and be logged in on your microsoft Entra account to access the account keys for the storage account.

You will also need to have [azure copy installed](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10) as well.

## Execution

Run Shell interactively and be prompted to input the storage account name and container name.

```shell
bash generate-container-sas-token.sh
```

Run shell non interactively by providing parameters

```shell
bash generate-container-sas-token.sh <storage_account> <container_name>
```

Once the command is ran if you have the correct permission and the right account/container names the command will return a raw string which is the sas token. Copy this token to use in the az copy operation.

Fill the command with the relevant info and append the sas token to the end. Easiest way to upload the file is to run the az copy command from the same directory as the file and just specify the file name in the local path to file section.

```shell
azcopy copy "<local path to file to upload>" https://<storageaccount name>.blob.core.windows.net/<storageconatiner name>?<sas token>"
```

Once ran if successful you should see the command return that it has done a write operation to the storage container.
