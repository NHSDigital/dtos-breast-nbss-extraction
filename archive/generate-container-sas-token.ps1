#Requires -Version 5.1
<#
.SYNOPSIS
    Generates a SAS token for an Azure Blob Storage container.

.DESCRIPTION
    Accepts a storage account name and container name as parameters.
    Generates a write-only SAS token valid for 30 minutes.

.PARAMETER StorageAccount
    The name of the Azure Storage Account.

.PARAMETER ContainerName
    The name of the blob container.

.EXAMPLE
    .\generate-container-sas-token.ps1 -StorageAccount "mystorageaccount" -ContainerName "mycontainer"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$StorageAccount,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Prompt for parameters if not provided.
if ([string]::IsNullOrWhiteSpace($StorageAccount)) {
    $StorageAccount = Read-Host "Enter storage account name"
}

if ([string]::IsNullOrWhiteSpace($ContainerName)) {
    $ContainerName = Read-Host "Enter container name"
}

if ([string]::IsNullOrWhiteSpace($StorageAccount) -or [string]::IsNullOrWhiteSpace($ContainerName)) {
    Write-Error "Storage account and container name are required."
    exit 1
}

# Expiry time for the SAS token is set to 30 minutes from the current time.
$expiry = (Get-Date).ToUniversalTime().AddMinutes(30).ToString("yyyy-MM-ddTHH:mmZ")

# Azure CLI command to retrieve the storage account key with FULL permissions.
$accountKey = az storage account keys list `
    --account-name $StorageAccount `
    --query "[?permissions=='FULL'] | [0].value" `
    --output tsv

if ([string]::IsNullOrWhiteSpace($accountKey)) {
    Write-Error "Failed to retrieve storage account key for '$StorageAccount'."
    exit 1
}

# Generate the SAS token for the specified container with write permissions and HTTPS only.
$sasToken = az storage container generate-sas `
    --name $ContainerName `
    --https-only `
    --permissions w `
    --expiry $expiry `
    --account-key $accountKey `
    --account-name $StorageAccount `
    --output tsv

Write-Output $sasToken
