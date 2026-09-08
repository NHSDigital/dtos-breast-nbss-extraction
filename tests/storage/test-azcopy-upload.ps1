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

$containerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"
$fileName = Split-Path -Leaf $LocalFilePath

Write-Host "Container endpoint: $containerUrl"
Write-Host "File to upload: $LocalFilePath"

if ($SasToken) {
    Write-Host "Test AzCopy upload using SAS token..."
    azcopy copy `"$LocalFilePath`" `"$containerUrl?$SasToken`" --from-to=LocalBlob --overwrite=true --blob-type=BlockBlob --log-level=INFO

    Write-Host "Verifying the blob exists via SAS URL ..."
    azcopy list `"$containerUrl?$SasToken`" --prefix $fileName --output-type json
}
else {
    Write-Host ""
    Write-Information "Skipping SAS token upload. To generate one:"
    Write-Information "az storage container generate-sas --account-name $StorageAccountName --name $ContainerName --permissions racwdl --https-only --expiry 2026-12-31T23:59:59Z --auth-mode login"
    Write-Host ""
}

if (-not $TenantId) {
    $TenantId = az account show --query tenantId -o tsv 2>$null

    if (-not $TenantId) {
        Write-Host ""
        Write-Warning "Azure CLI login not present. Please run the following before testing with Entra ID:"
        Write-Host "az login --tenant <tenant-id> --use-device-code"
        Write-Host "azcopy login --tenant-id <tenant-id>"
        exit 1
    }
}
# https://learn.microsoft.com/en-us/azure/storage/common/storage-ref-azcopy-configuration-settings

Write-Host "Logging in AzCopy with PowerShell credentials..."
azcopy login --tenant-id $TenantId --login-type pscred

Write-Host ""
Write-Host "Uploading with Entra ID authentication..."
azcopy copy "$LocalFilePath" "$containerUrl" --from-to=LocalBlob --overwrite=true --blob-type=BlockBlob --log-level=INFO
