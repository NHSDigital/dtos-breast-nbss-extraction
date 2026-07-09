#!/bin/bash

set -euo pipefail

# Accepts two parameters: storage account name and container name.
storageAccount="${1:-}"
containerName="${2:-}"

# If either parameter is not provided, prompt the user for input.
if [[ -z "$storageAccount" ]]; then
    read -r -p "Enter storage account name: " storageAccount
fi

if [[ -z "$containerName" ]]; then
    read -r -p "Enter container name: " containerName
fi

if [[ -z "$storageAccount" || -z "$containerName" ]]; then
    echo "Error: storage account and container name are required." >&2
    exit 1
fi

# Expiry time for the SAS token is set to 30 minutes from the current time.
expiry=$(date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ')

# Azure CLI command to retrieve the storage account key with FULL permissions.
accountKey=$(az storage account keys list \
    --account-name "$storageAccount" \
    --query "[?permissions=='FULL'] | [0].value" \
    --output tsv)

# generate the SAS token for the specified container with write permissions and HTTPS only and output the token to the console.
az storage container generate-sas \
    --name "$containerName" \
    --https-only \
    --permissions w \
    --expiry "$expiry" \
    --account-key "$accountKey" \
    --account-name "$storageAccount"
