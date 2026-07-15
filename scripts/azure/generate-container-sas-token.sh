#!/bin/bash

set -euo pipefail

# Accepts two parameters: storage account name and container name.
STORAGE_ACCOUNT="${1:-}"
CONTAINER_NAME="${2:-}"

# If either parameter is not provided, prompt the user for input.
# If the script is run in a non-interactive environment,it will exit with an error message if the parameters are not provided.
    if [[ -z "$STORAGE_ACCOUNT" ]]; then
        if [[ -t 0 ]]; then
            read -r -p "Enter storage account name: " STORAGE_ACCOUNT
        else
            echo "Error: storage account name is required as the first argument." >&2
            exit 1
        fi
    fi

    if [[ -z "$CONTAINER_NAME" ]]; then
        if [[ -t 0 ]]; then
            read -r -p "Enter container name: " CONTAINER_NAME
        else
            echo "Error: container name is required as the second argument." >&2
            exit 1
        fi
    fi

    if [[ -z "$STORAGE_ACCOUNT" || -z "$CONTAINER_NAME" ]]; then
        echo "Error: storage account and container name are required." >&2
        exit 1
    fi

# Expiry time for the SAS token is set to 30 minutes from the current time.
expiry=$(date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ')

# Azure CLI command to retrieve the storage account key with FULL permissions.
account_key=$(az storage account keys list \
    --account-name "$STORAGE_ACCOUNT" \
    --query "[?permissions=='FULL'] | [0].value" \
    --output tsv)

# Check if the account key was retrieved successfully.
    if [[ -z "$account_key" ]]; then
        echo "Error: failed to retrieve storage account key for '$STORAGE_ACCOUNT'." >&2
        exit 1
    fi

# generate the SAS token for the specified container with write permissions and HTTPS only and output the token to the console.
az storage container generate-sas \
    --name "$CONTAINER_NAME" \
    --https-only \
    --permissions w \
    --expiry "$expiry" \
    --account-key "$account_key" \
    --account-name "$STORAGE_ACCOUNT" \
    --output tsv
