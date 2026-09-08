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

function Test-AzCliLogin {
    [CmdletBinding()]
    param()

    try {
        $null = az account show --query id -o tsv 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Ensure-AzCliLogin {
    [CmdletBinding()]
    param(
        [string]$TenantId
    )

    if (Test-AzCliLogin) {
        return
    }

    Write-Host "No active Azure CLI session found. Signing in..." -ForegroundColor Yellow
    if ($TenantId) {
        az login --tenant $TenantId --output none | Out-Null
    }
    else {
        az login --output none | Out-Null
    }

    if ($LASTEXITCODE -ne 0) {
        throw "❌ Azure CLI login command failed. Please run 'az login' and retry."
    }

    if (-not (Test-AzCliLogin)) {
        throw "❌ Azure CLI login failed. Please run 'az login' and retry."
    }
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

$containerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Host "Parameters" -ForegroundColor Yellow
Write-Host "   Container endpoint: " -NoNewline
Write-Host "$containerUrl" -ForegroundColor DarkYellow
Write-Host "   File to upload: " -NoNewline
Write-Host "$LocalFilePath" -ForegroundColor DarkYellow
Write-Host "Current user identity:" -ForegroundColor Yellow

$azAccount = az account show --query "{name:user.name,type:user.type}" -o json 2>$null
if ($LASTEXITCODE -eq 0 -and $azAccount) {
    $accountInfo = $azAccount | ConvertFrom-Json
    Write-Host "   Current user: " -NoNewline
    Write-Host "$($accountInfo.name)" -ForegroundColor DarkYellow
    Write-Host "   Account type: " -NoNewline
    Write-Host "$($accountInfo.type)" -ForegroundColor DarkYellow
}
else {
    Write-Host "   Current user: " -NoNewline
    Write-Host "not signed in" -ForegroundColor DarkYellow
    Write-Host "   Account type: " -NoNewline
    Write-Host "not available" -ForegroundColor DarkYellow
}

if (-not $SasToken -and $GenerateSasToken.IsPresent) {
    Write-Host ""
    Write-Host "Generating a new token..." -ForegroundColor Yellow

    Ensure-AzCliLogin -TenantId $TenantId

    $expiryUtc = (Get-Date).ToUniversalTime().AddDays(5).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $SasToken = az storage container generate-sas --account-name $StorageAccountName --name $ContainerName --permissions ac --expiry $expiryUtc --as-user --auth-mode login -o tsv

    if ($LASTEXITCODE -ne 0 -or -not $SasToken) {
        throw "❌ Failed to generate a SAS token with Azure CLI. Ensure you have at minimum the Storage Blob Data Contributor permissions and retry. Exit code = $LASTEXITCODE"
    }

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

    if ($LASTEXITCODE -ne 0) {
        throw "❌ AzCopy upload with SAS token failed. Exit code = $LASTEXITCODE"
    }

    Write-Host "   ✅ Successfully uploaded using SAS token via AzCopy."
    exit 0
}

Write-Host "Checking Azure session..." -ForegroundColor Yellow
Ensure-AzCliLogin -TenantId $TenantId

if (-not $TenantId) {
    $TenantId = az account show --query tenantId -o tsv

    if ($LASTEXITCODE -ne 0) {
        throw "❌ Failed to read tenant ID from Azure CLI context. Exit code = $LASTEXITCODE"
    }
}

if (-not $TenantId) {
    throw "❌ Tenant ID could not be determined from Azure CLI context."
}

Write-Host "   ✅ Connected to tenant " -NoNewline
Write-Host "$TenantId." -ForegroundColor DarkYellow

Write-Host "Uploading with AzCopy (auth=Entra)..." -ForegroundColor Yellow

azcopy login --tenant-id $TenantId --login-type azcli

if ($LASTEXITCODE -ne 0) {
    throw "❌ AzCopy login with Azure CLI credentials failed. Exit code = $LASTEXITCODE"
}

azcopy copy "$LocalFilePath" "$containerUrl" --from-to=LocalBlob --overwrite=true --blob-type=BlockBlob --log-level=INFO

if ($LASTEXITCODE -ne 0) {
    throw "❌ AzCopy upload with Entra authentication failed. Exit code = $LASTEXITCODE"
}

Write-Host "   ✅ Successfully uploaded."
Write-Host ""
