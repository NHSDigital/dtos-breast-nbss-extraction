[CmdletBinding()]
param(
    [string]$StorageAccountName = "sanbssedevupload",
    [string]$ContainerName = "uploads",
    [string]$LocalFilePath = "",
    [string]$TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$containerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Host "Parameters" -ForegroundColor Yellow
Write-Host "   Container endpoint: " -NoNewline
Write-Host "$containerUrl" -ForegroundColor DarkYellow
Write-Host "   File to upload: " -NoNewline
Write-Host "$LocalFilePath" -ForegroundColor DarkYellow

Write-Host "Signing in with Azure CLI..." -ForegroundColor Yellow
az login --tenant $TenantId --output none

if ($LASTEXITCODE -ne 0) {
    throw "❌ Azure CLI login failed. Exit code = $LASTEXITCODE"
}

Write-Host "Signing in to AzCopy with Azure CLI credentials..." -ForegroundColor Yellow
azcopy login --login-type azcli --tenant-id $TenantId
if ($LASTEXITCODE -ne 0) {
    throw "❌ AzCopy login with Azure CLI credentials failed. Exit code = $LASTEXITCODE"
}

Write-Host "Uploading with AzCopy (auth=Entra)..." -ForegroundColor Yellow
# Upload-only role has no blobs/read, so skip the pre-upload existence check and post-upload length check.
# Overwrites are still blocked server-side because blobs/add/action can only create new blobs.
azcopy copy "$LocalFilePath" "$containerUrl" `
    --from-to=LocalBlob `
    --overwrite=true `
    --blob-type=BlockBlob `
    --log-level=INFO `
    --put-md5

if ($LASTEXITCODE -ne 0) {
    throw "❌ AzCopy upload with Entra authentication failed. Exit code = $LASTEXITCODE"
}

Write-Host "   ✅ Successfully uploaded."
Write-Host ""
