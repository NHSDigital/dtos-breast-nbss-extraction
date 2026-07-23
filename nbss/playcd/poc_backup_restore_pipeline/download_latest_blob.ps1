<#
.SYNOPSIS
    Downloads the latest blob from an Azure Storage Account container and verifies its SHA-256 hash against Azure Key Vault.

.DESCRIPTION
    Lists all blobs in the specified container, identifies the most recently modified blob, downloads it locally, computes its SHA-256 hash, and compares it against the value stored in Azure Key Vault.

.PARAMETER ContainerName
    Name of the Azure Storage container.

.PARAMETER StorageAccountName
    Name of the Azure Storage Account.

.PARAMETER KeyVaultName
    Name of the Azure Key Vault  e.g. nbsse-dev-kv.

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
    [string]$StorageAccountName,

    [string]$KeyVaultName = "nbsse-dev-kv"
)

$ErrorActionPreference = "Stop"
$env:AZURE_CORE_ONLY_SHOW_ERRORS = "true"

# ---------------------------------------------------------------------------
# 1. Get the latest blob and download it
# ---------------------------------------------------------------------------
$latest = (az storage blob list --container-name $ContainerName --account-name $StorageAccountName --output json | ConvertFrom-Json) | Sort-Object {$_.properties.lastModified} -Descending | Select-Object -First 1 -ExpandProperty name

Write-Host "Latest blob: $latest"

az storage blob download --container-name $ContainerName --account-name $StorageAccountName --name $latest --file (Join-Path $PSScriptRoot $latest)

$localFile = Join-Path $PSScriptRoot $latest
Write-Host "Download complete: $localFile"

# ---------------------------------------------------------------------------
# 2. Compute SHA-256 hash of downloaded file
# ---------------------------------------------------------------------------
$hash = (Get-FileHash -LiteralPath $localFile -Algorithm SHA256).Hash
Write-Host "SHA-256    : $hash"

# ---------------------------------------------------------------------------
# 3. Retrieve stored hash from Key Vault and compare
# ---------------------------------------------------------------------------
$zipName = [System.IO.Path]::GetFileNameWithoutExtension($latest)
$secretName = "$zipName-hash"
Write-Host "Secret name: $secretName"

$storedHash = az keyvault secret show --vault-name $KeyVaultName --name $secretName --query value --output tsv

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to retrieve secret '$secretName' from Key Vault '$KeyVaultName'."
    exit 1
}

Write-Host "Stored hash: $storedHash"

if ($hash -eq $storedHash) {
    Write-Host "MATCH: Downloaded file hash matches the stored hash." -ForegroundColor Green
} else {
    Write-Warning "MISMATCH: Downloaded file hash does NOT match the stored hash." -ForegroundColor Red
    Write-Host "  Local : $hash"
    Write-Host "  Stored: $storedHash"
    exit 1
}
