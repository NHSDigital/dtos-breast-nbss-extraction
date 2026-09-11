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

Write-Host "Container endpoint: " -NoNewline
Write-Host "$containerUrl" -ForegroundColor DarkYellow

Write-Host "File to upload: " -NoNewline
Write-Host "$LocalFilePath" -ForegroundColor DarkYellow

$currentContext = Get-AzContext -ErrorAction SilentlyContinue
if ($currentContext -and $currentContext.Account -and $currentContext.Account.Id) {
    Write-Host "Current user: " -NoNewline
    Write-Host "$($currentContext.Account.Id)" -ForegroundColor DarkYellow
    Write-Host "Account type: " -NoNewline
    Write-Host "$($currentContext.Account.Type)" -ForegroundColor DarkYellow
}
else {
    $azAccount = az account show --query user.name -o tsv 2>$null
    if ($azAccount) {
        Write-Host "Current user: " -NoNewline
        Write-Host "$azAccount" -ForegroundColor DarkYellow
        Write-Host "Account type: " -NoNewline
        Write-Host "Azure CLI" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "Current user: " -NoNewline
        Write-Host "not signed in" -ForegroundColor DarkYellow
        Write-Host "Account type: " -NoNewline
        Write-Host "not available" -ForegroundColor DarkYellow
    }
}

Write-Host ""

if (-not $SasToken -and $GenerateSasToken.IsPresent) {
    Write-Host "⚠️ No SAS token provided. Generating a new token..."
    $SasToken = New-AzStorageContainerSASToken -Name $ContainerName -Context (New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount) -Permission ac -Expiry (Get-Date).AddDays(5)

    Write-Host "Generated SAS token: " -NoNewLine
    Write-Host "$SasToken" -ForegroundColor Blue
}

if ($SasToken) {
    $normalisedSasToken = $SasToken.TrimStart("?")

    Write-Host "Uploading with SAS token using " -NoNewline
    Write-Host "Az.Storage" -ForegroundColor Yellow -NoNewline
    Write-Host "..."
    $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $normalisedSasToken

    Set-AzStorageBlobContent `
        -File $LocalFilePath `
        -Container $ContainerName `
        -Blob $fileName `
        -Context $storageContext `
        -Force | Out-Null

    $uploadedBlob = Get-AzStorageBlob -Context $storageContext -Container $ContainerName -Blob $fileName -ErrorAction SilentlyContinue
    if (-not $uploadedBlob) {
        throw "❌ Failed to verify upload using SAS token. Blob '$fileName' was not found in container '$ContainerName'."
    }

    exit 0
}

Write-Host ""
Write-Host "ℹ️ Checking for existing Azure session..."
$currentContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $currentContext -or -not $currentContext.Tenant -or -not $currentContext.Tenant.Id) {
    $azTenantId = az account show --query tenantId -o tsv 2>$null
    if (-not $azTenantId) {
        $azTenantId = $TenantId
    }

    if (-not $azTenantId) {
        Write-Host ""
        Write-Host "⚠️ No current Azure CLI or Az context. Logging into Azure..."
        if ($TenantId) {
            Connect-AzAccount -Tenant $TenantId | Out-Null
        }
        else {
            Connect-AzAccount | Out-Null
        }
    }
    else {
        Write-Host "Logging into Azure PowerShell using tenant " -NoNewLine
        Write-Host "$azTenantId..." -ForegroundColor DarkYellow
        Connect-AzAccount -Tenant $azTenantId | Out-Null
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
Write-Host "ℹ️ Uploading with Entra ID using " -NoNewline
Write-Host "Az.Storage" -ForegroundColor Yellow -NoNewline
Write-Host "..."

$entraContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
Write-Host "   ✅ Created storage context with Entra ID authentication..."

Set-AzStorageBlobContent `
    -File $LocalFilePath `
    -Container $ContainerName `
    -Blob $fileName `
    -Context $entraContext `
    -Force | Out-Null
Write-Host "   ✅ Successfully uploaded using Entra ID authentication."
Write-Host ""
