[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName = "sanbssedevupload",
    [string]$ContainerName = "uploads",
    [string]$LocalFilePath = "",
    [string]$SasToken = "",
    [string]$TenantId = "",
    [switch]$GenerateSasToken
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

$fileName = Split-Path -Leaf $LocalFilePath
$containerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Host "Parameters" -ForegroundColor Yellow
Write-Host "   Container endpoint: " -NoNewline
Write-Host "$containerUrl" -ForegroundColor DarkYellow
Write-Host "   File to upload: " -NoNewline
Write-Host "$LocalFilePath" -ForegroundColor DarkYellow

Write-Host "Current user identity:" -ForegroundColor Yellow
$currentContext = Get-AzContext -ErrorAction SilentlyContinue
if ($currentContext -and $currentContext.Account -and $currentContext.Account.Id) {
    Write-Host "   Current user: " -NoNewline
    Write-Host "$($currentContext.Account.Id)" -ForegroundColor DarkYellow
    Write-Host "   Account type: " -NoNewline
    Write-Host "$($currentContext.Account.Type)" -ForegroundColor DarkYellow
}
else {
    $azAccount = az account show --query user.name -o tsv 2>$null
    if ($azAccount) {
        Write-Host "   Current user: " -NoNewline
        Write-Host "$azAccount" -ForegroundColor DarkYellow
        Write-Host "   Account type: " -NoNewline
        Write-Host "Azure CLI" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "   Current user: " -NoNewline
        Write-Host "not signed in" -ForegroundColor DarkYellow
        Write-Host "   Account type: " -NoNewline
        Write-Host "not available" -ForegroundColor DarkYellow
    }
}

Write-Host ""

if (-not $SasToken -and $GenerateSasToken.IsPresent) {
    Write-Host ""
    Write-Host "Generating a new token..." -ForegroundColor Yellow

    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $currentContext -or -not $currentContext.Tenant -or -not $currentContext.Tenant.Id) {
        if ($TenantId) {
            Connect-AzAccount -Tenant $TenantId | Out-Null
        }
        else {
            Connect-AzAccount | Out-Null
        }
    }

    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $currentContext -or -not $currentContext.Tenant -or -not $currentContext.Tenant.Id) {
        throw "❌ Context cannot be null. Please log in using Connect-AzAccount before generating a SAS token."
    }

    $sasContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    $SasToken = New-AzStorageContainerSASToken -Name $ContainerName -Context $sasContext -Permission ac -Expiry (Get-Date).AddDays(5)

    Write-Host "   Token: " -NoNewline
    Write-Host "$SasToken" -ForegroundColor Blue
}

if ($SasToken) {
    $normalisedSasToken = $SasToken.TrimStart("?")
    $sasDestinationUrl = "${containerUrl}?$normalisedSasToken"

    Write-Host ""
    Write-Host "ℹ️ Uploading with SAS token using " -NoNewline
    Write-Host "AzCopy" -ForegroundColor Cyan -NoNewline
    Write-Host "..."
    azcopy copy "$LocalFilePath" "$sasDestinationUrl" --from-to=LocalBlob --overwrite=true --blob-type=BlockBlob --log-level=INFO

    Write-Host "   ✅ Successfully uploaded using SAS token via AzCopy."
    exit 0
}

Write-Host ""
Write-Host "Checking Azure session..." -ForegroundColor Yellow
$currentContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $currentContext -or -not $currentContext.Tenant -or -not $currentContext.Tenant.Id) {
    if ($TenantId) {
        Connect-AzAccount -Tenant $TenantId | Out-Null
    }
    else {
        Connect-AzAccount | Out-Null
    }
}

$currentContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $currentContext -or -not $currentContext.Tenant -or -not $currentContext.Tenant.Id) {
    throw "❌ Context cannot be null. Please log in using Connect-AzAccount before creating the storage context."
}

if (-not $TenantId) {
    $TenantId = $currentContext.Tenant.Id
}

Write-Host "   ✅ Connected to tenant " -NoNewline
Write-Host "$TenantId." -ForegroundColor DarkYellow

Write-Host ""
Write-Host "Uploading with Entra ID using " -NoNewline
Write-Host "AzCopy" -ForegroundColor Cyan -NoNewline
Write-Host "..."

azcopy login --tenant-id $TenantId --login-type pscred
azcopy copy "$LocalFilePath" "$containerUrl" --from-to=LocalBlob --overwrite=true --blob-type=BlockBlob --log-level=INFO

Write-Host "   ✅ Successfully uploaded using Entra ID authentication with AzCopy."
Write-Host ""
