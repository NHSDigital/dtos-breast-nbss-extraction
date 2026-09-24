<#
.SYNOPSIS
    Downloads the latest blob from an Azure Storage Account container.

.DESCRIPTION
    Lists all blobs in the specified container, identifies the most recently modified blob, and downloads it locally.

.PARAMETER ContainerName
    Name of the Azure Storage container.

.PARAMETER StorageAccountName
    Name of the Azure Storage Account.

.EXAMPLE
    .\download_latest_blob.ps1 -ContainerName "bso-001-container" -StorageAccountName "bsrtestdatalake"

.NOTES
    Ensure `az login` has been run before executing this script.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$ContainerName,

    [Parameter(Mandatory)]
    [string]$StorageAccountName
)

$ErrorActionPreference = "Stop"
$env:AZURE_CORE_ONLY_SHOW_ERRORS = "true"

# ---------------------------------------------------------------------------
# 1. Get the latest blob and download it
# ---------------------------------------------------------------------------
$latest = (az storage blob list --container-name $ContainerName --account-name $StorageAccountName --output json | ConvertFrom-Json) | Sort-Object {$_.properties.lastModified} -Descending | Select-Object -First 1 -ExpandProperty name

Write-Host "Latest blob: $latest"

$pipelineRoot = Split-Path $PSScriptRoot -Parent
az storage blob download --container-name $ContainerName --account-name $StorageAccountName --name $latest --file (Join-Path $pipelineRoot $latest)

$localFile = Join-Path $pipelineRoot $latest
Write-Host "Download complete: $localFile"
