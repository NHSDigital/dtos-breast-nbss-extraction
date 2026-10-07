#Requires -Version 5.1
<#
.SYNOPSIS
    Ensures winget, Azure CLI and AzCopy are installed, pinned to known-good versions.
.PARAMETER ToolVersionsFile
    Path to the JSON file holding the pinned tool versions.
#>
param(
    [string]$ToolVersionsFile = (Join-Path $PSScriptRoot '..\..\tool_versions.json')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ToolVersionsFile)) {
    throw "Tool versions file not found: $ToolVersionsFile"
}
$ToolVersions = Get-Content -LiteralPath $ToolVersionsFile -Raw | ConvertFrom-Json

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Install-Winget {
    Write-Host 'winget not found. Attempting to install the App Installer (winget)...'

    # winget ships with the Microsoft.DesktopAppInstaller package on Windows 10/11.
    try {
        $progressPreference = 'SilentlyContinue'
        $tempInstaller = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller.msixbundle'
        $downloadUrl = 'https://aka.ms/getwinget'

        Write-Host "Downloading App Installer from $downloadUrl ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing

        Write-Host 'Registering App Installer package...'
        Add-AppxPackage -Path $tempInstaller

        Remove-Item -Path $tempInstaller -Force -ErrorAction SilentlyContinue
    }
    catch {
        throw "Failed to install winget automatically. Install 'App Installer' from the Microsoft Store, then re-run this script. Details: $($_.Exception.Message)"
    }

    if (-not (Test-CommandExists -Name 'winget')) {
        throw "winget is still not available after installation. Restart the shell (or the machine) and re-run this script."
    }

    Write-Host 'winget installed successfully.'
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Version
    )

    $installed = winget list --exact --id $Id 2>$null | Select-String -SimpleMatch $Id
    if ($installed) {
        Write-Host "$DisplayName is already installed. Skipping."
        return
    }

    Write-Host "Installing $DisplayName ($Id) version $Version ..."
    winget install --exact --id $Id --version $Version `
        --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install $DisplayName ($Id) version $Version. winget exit code: $LASTEXITCODE"
    }

    Write-Host "$DisplayName installed successfully."
}

# 1. Ensure winget is available.
if (-not (Test-CommandExists -Name 'winget')) {
    Install-Winget
}
else {
    Write-Host 'winget is already installed.'
}

# 2. Ensure pinned tools are installed.
foreach ($toolName in 'AzureCli', 'AzCopy') {
    $tool = $ToolVersions.$toolName
    if (-not $tool) {
        throw "'$toolName' is missing from $ToolVersionsFile"
    }
    Install-WingetPackage -DisplayName $tool.DisplayName -Id $tool.WingetId -Version $tool.Version
}

Write-Host 'All tools are installed.'
