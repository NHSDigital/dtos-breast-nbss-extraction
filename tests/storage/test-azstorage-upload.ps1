[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    [string]$ContainerName = "uploads",
    [string]$LocalFilePath = "",
    [string]$SasToken = "",
    [string]$TenantId = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TrimmedSasToken {
    param(
        [string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        return ""
    }

    return $Token.TrimStart("?")
}

if (-not $LocalFilePath) {
    $LocalFilePath = Join-Path $PSScriptRoot "sample-upload.txt"
}

if (-not (Test-Path $LocalFilePath)) {
    $timestamp = Get-Date -Format o
    $content = @(
        "Storage upload smoke test",
        "Generated at: $timestamp",
        "Container: $ContainerName",
        "Storage account: $StorageAccountName"
    ) -join [Environment]::NewLine

    Set-Content -Path $LocalFilePath -Value $content -Encoding UTF8
    Write-Host "Created a sample file for upload testing: $LocalFilePath"
}

$fileName = Split-Path -Leaf $LocalFilePath
$containerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Host "Container endpoint: $containerUrl"
Write-Host "File to upload: $LocalFilePath"

$sasToken = Get-TrimmedSasToken -Token $SasToken

if ($sasToken) {
    Write-Host "Uploading with SAS token using Az.Storage..."
    $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $sasToken

    Set-AzStorageBlobContent `
        -File $LocalFilePath `
        -Container $ContainerName `
        -Blob $fileName `
        -Context $storageContext `
        -Force | Out-Null

    # Write-Host "Verifying the blob exists via SAS-authenticated context..."
    # $uploadedBlob = Get-AzStorageBlob -Container $ContainerName -Blob $fileName -Context $storageContext
    # Write-Host "Uploaded blob: $($uploadedBlob.Name)"
    # Write-Host "Blob length: $($uploadedBlob.Length)"
    exit 0
}

if (-not $TenantId) {
    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($currentContext -and $currentContext.Tenant -and $currentContext.Tenant.Id) {
        $TenantId = $currentContext.Tenant.Id
    }
}

if (-not $TenantId) {
    Write-Warning "No SAS token was provided and no Azure tenant was discovered in the current PowerShell session."
    Write-Host ""
    Write-Host "To use Entra ID, please first sign in with:"
    Write-Host "Connect-AzAccount -Tenant <tenant-id>"
    Write-Host ""
    Write-Host "Then rerun this script without -SasToken. Please pass -TenantId <tenant-id> for the script to connect automatically ."
    exit 1
}

if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    Write-Host "Signing in with Entra ID using tenant $TenantId..."
    Connect-AzAccount -Tenant $TenantId | Out-Null
}

$entraContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

Write-Host ""
Write-Host "Uploading with Entra ID authentication using Az.Storage..."
Set-AzStorageBlobContent `
    -File $LocalFilePath `
    -Container $ContainerName `
    -Blob $fileName `
    -Context $entraContext `
    -Force | Out-Null

# Write-Host "Verifying the blob exists via Entra-authenticated context..."
# $uploadedEntraBlob = Get-AzStorageBlob -Container $ContainerName -Blob $fileName -Context $entraContext
# Write-Host "Uploaded blob: $($uploadedEntraBlob.Name)"
# Write-Host "Blob length: $($uploadedEntraBlob.Length)"
