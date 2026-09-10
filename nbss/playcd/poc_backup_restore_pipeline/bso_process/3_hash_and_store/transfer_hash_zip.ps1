<#
.SYNOPSIS
    SHA-256 hashes a zip file and stores the hash as a secret in Azure Key Vault.

.DESCRIPTION
    Computes the SHA-256 hash of a zip file and pushes it to Azure Key Vault
    under a secret named:  {YYYYMMDD}-{BsoCode}-hash
    e.g. 20260715-A0001344-hash

.PARAMETER BsoCode
    BSO code to embed in the secret name  e.g. A0001344.

.PARAMETER KeyVaultName
    Name of the Azure Key Vault  e.g. nbsse-dev-kv.

.PARAMETER ZipPath
    Path to the zip file to hash.
    Defaults to the most recently modified *.zip in the script directory.

.EXAMPLE
    .\transfer_hash_zip.ps1 -BsoCode "A0001344" -KeyVaultName "nbsse-dev-kv"

.EXAMPLE
    .\transfer_hash_zip.ps1 -BsoCode "A0001344" -KeyVaultName "nbsse-dev-kv" -ZipPath "C:\Backups\backup.zip"

.NOTES
    Key Vault secret names only allow letters, numbers, and hyphens — no underscores.
    Ensure `az login` has been run before executing this script.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$BsoCode,

    [string]$KeyVaultName = "nbsse-dev-kv",

    [string]$ZipPath = ""
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1. Resolve zip file
# ---------------------------------------------------------------------------
if ($ZipPath -eq "") {
    $zipFiles = Get-ChildItem -Path (Split-Path $PSScriptRoot -Parent) -Filter "*.zip" -File |
                Sort-Object LastWriteTime -Descending

    if ($zipFiles.Count -eq 0) {
        Write-Warning "No *.zip file found in '$PSScriptRoot'. Supply -ZipPath explicitly."
        exit 1
    }

    if ($zipFiles.Count -gt 1) {
        Write-Warning "Multiple zip files found. Using the most recently modified: $($zipFiles[0].Name)"
    }

    $ZipPath = $zipFiles[0].FullName
}

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    Write-Warning "Zip file not found: '$ZipPath'"
    exit 1
}

Write-Host "Zip file   : $ZipPath"

# ---------------------------------------------------------------------------
# 2. Compute SHA-256 hash
# ---------------------------------------------------------------------------
$hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
Write-Host "SHA-256    : $hash"

# ---------------------------------------------------------------------------
# 3. Build secret name: {YYYYMMDD}-{BsoCode}-hash  (hyphens only — no underscores)
# ---------------------------------------------------------------------------
$date       = (Get-Date -Format "yyyyMMdd")
$secretName = "$date-$BsoCode-hash"
Write-Host "Secret name: $secretName"

# ---------------------------------------------------------------------------
# 4. Verify az CLI is available and user is logged in
# ---------------------------------------------------------------------------
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') not found on PATH. Install from https://aka.ms/installazurecliwindows"
}

az account show --output none 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "You are not logged in to Azure CLI. Launching 'az login' ..."
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Azure CLI login failed. Cannot continue."
        exit 1
    }
}

Write-Host "Azure CLI  : logged in as $((az account show --query user.name -o tsv))"

# ---------------------------------------------------------------------------
# 5. Push hash to Azure Key Vault
# ---------------------------------------------------------------------------
Write-Host "Storing secret in Key Vault '$KeyVaultName' ..."

$azOutput = az keyvault secret set `
    --vault-name $KeyVaultName `
    --name       $secretName `
    --value      $hash `
    --output     json 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "az keyvault secret set failed (exit $LASTEXITCODE):`n$azOutput"
}

$secretId = ($azOutput | ConvertFrom-Json).id
Write-Host "Secret stored successfully."
Write-Host "Secret ID  : $secretId"
