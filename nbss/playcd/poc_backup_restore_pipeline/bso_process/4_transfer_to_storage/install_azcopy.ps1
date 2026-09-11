<#
.SYNOPSIS
    Downloads and installs AzCopy v10 for Windows, then adds it to the User PATH.

.DESCRIPTION
    This script performs the following steps:
      1. Downloads the latest AzCopy v10 Windows 64-bit ZIP from Microsoft.
      2. Extracts azcopy.exe into the install folder (default C:\azcopy).
      3. Adds the install folder to the current user's PATH environment variable (only if it isn't already present).
      4. Verifies that azcopy is available and prints its version.

    Reopen PowerShell or VS Code after running this script so the updated PATH
    is picked up by new terminal sessions.

.PARAMETER InstallPath
    Folder to install azcopy.exe into. Defaults to "C:\Program Files (x86)\azcopy".

.EXAMPLE
    .\install_azcopy.ps1

.EXAMPLE
    .\install_azcopy.ps1 -InstallPath "D:\tools\azcopy"

.NOTES
    The default InstallPath is under Program Files (x86), so this script must be
    run as Administrator unless a different, user-writable InstallPath is given.
#>

param (
    # Folder to install azcopy.exe into
    [string]$InstallPath = "C:\Program Files (x86)\azcopy"
)

$ErrorActionPreference = "Stop"

$downloadUrl = "https://aka.ms/downloadazcopy-v10-windows"
$zipPath = Join-Path $env:TEMP "azcopy.zip"
$extractPath = Join-Path $env:TEMP "azcopy_extract"

Write-Host "Downloading AzCopy from $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Write-Host "Extracting AzCopy..."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$azcopyExe = Get-ChildItem -Path $extractPath -Filter "azcopy.exe" -Recurse | Select-Object -First 1
if (-not $azcopyExe) {
    throw "azcopy.exe was not found in the downloaded archive."
}

if (-not (Test-Path $InstallPath)) {
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
}
Write-Host "Installing azcopy.exe to $InstallPath..."
Copy-Item -Path $azcopyExe.FullName -Destination $InstallPath -Force

Remove-Item $zipPath -Force
Remove-Item $extractPath -Recurse -Force

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $InstallPath) {
    Write-Host "Adding $InstallPath to the User PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallPath", "User")
    $env:Path += ";$InstallPath"
} else {
    Write-Host "$InstallPath is already in the User PATH."
}

Write-Host "Verifying AzCopy installation..."
& (Join-Path $InstallPath "azcopy.exe") --version

Write-Host "AzCopy installed successfully. Close and reopen PowerShell or VS Code so the updated PATH is loaded in new sessions."
