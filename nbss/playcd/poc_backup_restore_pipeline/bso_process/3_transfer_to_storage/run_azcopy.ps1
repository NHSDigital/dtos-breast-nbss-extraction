[CmdletBinding()]
param(
    [string]$StorageAccountName = "sanbssedevupload",
    [string]$ContainerName = "uploads",
    [string]$LocalFilePath = "",
    [string]$TenantId = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$containerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Host "Parameters" -ForegroundColor Yellow
Write-Host "   Container endpoint: " -NoNewline
Write-Host "$containerUrl" -ForegroundColor DarkYellow
Write-Host "   File to upload: " -NoNewline
Write-Host "$LocalFilePath" -ForegroundColor DarkYellow

Write-Host "Uploading with AzCopy (auth=Entra)..." -ForegroundColor Yellow

azcopy login --tenant-id $TenantId
# do we want the --overwrite=true flag or not?
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
