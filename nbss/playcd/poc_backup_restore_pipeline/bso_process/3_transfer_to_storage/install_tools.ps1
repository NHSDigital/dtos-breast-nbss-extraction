#Requires -Version 5.1
<#
.SYNOPSIS
    Ensures winget, Azure CLI and AzCopy are installed, pinned to known-good versions.
#>

$ErrorActionPreference = 'Stop'

# Pinned versions so tool behaviour stays stable over time.
$AzureCliVersion = '2.90.0'
$AzCopyVersion   = '10.32.8'

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

    $installed = winget list --exact --id $Id --accept-source-agreements --disable-interactivity 2>$null |
        Select-String -SimpleMatch $Id
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

# 2. Ensure Azure CLI is installed (pinned version).
Install-WingetPackage -DisplayName 'Azure CLI' -Id 'Microsoft.AzureCLI' -Version $AzureCliVersion

# 3. Ensure AzCopy is installed (pinned version).
Install-WingetPackage -DisplayName 'AzCopy' -Id 'Microsoft.Azure.AZCopy.10' -Version $AzCopyVersion

Write-Host 'All tools are installed.'
