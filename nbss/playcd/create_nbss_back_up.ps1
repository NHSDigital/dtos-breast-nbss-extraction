<#
.SYNOPSIS
    Creates a timestamped zip backup of NBSS folders and InterSystems Caché database files.

.DESCRIPTION
    This script performs the following steps:
      1. Stops the running InterSystems Caché instance.
      2. Creates a zip archive containing:
            - NBSS\Attachments  (all contents)
            - NBSS\Letters      (all contents)
            - NBSS\Labels       (all contents)
            - All CACHE.DAT database files found under InterSystems\Cache
            - InterSystems\Cache\mgr\BACKUP_CACHE.DAT (latest backup only)
      3. Saves the zip to the same folder the script is run from, named:
            NBSS_Backup_YYYYMMDD_HHmm.zip
      4. Restarts the Caché instance once the zip is complete.

    Use the -NbssRoot and -CacheRoot parameters if NBSS or InterSystems
    are installed on a different drive to the default (C:\).

.PARAMETER NbssRoot
    Root folder where NBSS is installed. Defaults to C:\NBSS.

.PARAMETER CacheRoot
    Root folder where InterSystems is installed. Defaults to C:\InterSystems.

.EXAMPLE
    # Run with defaults (both on C:\)
    .\create_nbss_back_up.ps1

.EXAMPLE
    # NBSS on D:\ and InterSystems on E:\
    .\create_nbss_back_up.ps1 -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"

.EXAMPLE
    # Only NBSS is on a different drive
    .\create_nbss_back_up.ps1 -NbssRoot "D:\NBSS"

.NOTES
    Must be run as Administrator.
    Caché will be stopped during the backup and restarted automatically on completion.
#>

#Requires -RunAsAdministrator
param (
    # Root path where NBSS is installed  e.g. C:\NBSS or D:\NBSS
    [string]$NbssRoot   = "C:\NBSS",
    # Root path where InterSystems Cache is installed  e.g. C:\InterSystems or D:\InterSystems
    [string]$CacheRoot  = "C:\InterSystems"
)

$ErrorActionPreference = "Stop"

# Derived paths from parameters
$ccontrol  = Join-Path $CacheRoot "Cache\bin\ccontrol.exe"
$cacheDat  = Join-Path $CacheRoot "Cache"
$backupDat = Join-Path $CacheRoot "Cache\mgr\BACKUP_CACHE.DAT"

if (-not (Test-Path $ccontrol)) { throw "ccontrol.exe not found at '$ccontrol'. Verify -CacheRoot." }
if (-not (Test-Path $cacheDat)) { throw "Cache folder not found at '$cacheDat'. Verify -CacheRoot." }

$timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$zipPath   = Join-Path $PSScriptRoot "NBSS_Backup_$timestamp.zip"

function Write-Log { param([string]$m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" }

Write-Log "NBSS root   : $NbssRoot"
Write-Log "Cache root  : $CacheRoot"

# Stop Cache
Write-Log "Stopping Cache..."
$LASTEXITCODE = 0
& $ccontrol stop CACHE quietly
if ($LASTEXITCODE -ne 0) { throw "Failed to stop Cache via ccontrol (exit code $LASTEXITCODE). Check -CacheRoot and the Cache instance name." }
$waited = 0
while ((Get-Process -Name "cache" -ErrorAction SilentlyContinue) -and $waited -lt 60) {
    Start-Sleep -Seconds 5; $waited += 5
    Write-Log "Waiting... ($waited s)"
}
if (Get-Process -Name "cache" -ErrorAction SilentlyContinue) { throw "Cache did not stop in time." }
Write-Log "Cache stopped."

# Caché was stopped — guarantee a restart attempt regardless of what happens next
$cacheRestartError = $null
try {
    # Build zip
    Write-Log "Creating zip: $zipPath"
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

    try {
        # NBSS folders — strip NbssRoot from path to build zip entry name
        foreach ($folder in @("Attachments","Letters","Labels")) {
            $fullFolder = Join-Path $NbssRoot $folder
            if (-not (Test-Path $fullFolder)) { Write-Log "Skipping (not found): $fullFolder"; continue }
            Get-ChildItem $fullFolder -Recurse -File | ForEach-Object {
                $entry = $_.FullName.Substring(($NbssRoot.TrimEnd('\') + '\').Length).Replace("\","/")
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, 'Optimal') | Out-Null
            }
            Write-Log "Added: $fullFolder"
        }

        # CACHE.DAT files — strip CacheRoot from path to build zip entry name
        Get-ChildItem $cacheDat -Recurse -Filter "CACHE.DAT" -ErrorAction SilentlyContinue | ForEach-Object {
            $entry = $_.FullName.Substring(($CacheRoot.TrimEnd('\') + '\').Length).Replace("\","/")
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, 'Optimal') | Out-Null
            Write-Log "Added: $entry ($([math]::Round($_.Length/1MB,1)) MB)"
        }

        # BACKUP_CACHE.DAT (exact name only — excludes BACKUP_CACHE_1.DAT, BACKUP_CACHE_2.DAT, etc.)
        if (Test-Path $backupDat) {
            $entry = $backupDat.Substring(($CacheRoot.TrimEnd('\') + '\').Length).Replace("\","/")
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $backupDat, $entry, 'Optimal') | Out-Null
            Write-Log "Added: $entry ($([math]::Round((Get-Item $backupDat).Length/1MB,1)) MB)"
        } else {
            Write-Log "Skipping (not found): $backupDat"
        }
    } finally {
        $zip.Dispose()
    }

    Write-Log "Backup complete: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1MB,2)) MB)"
} finally {
    # Restart Caché — runs even if zip creation threw an exception.
    # Failures are recorded in $cacheRestartError and thrown after this block so
    # they do not suppress any in-flight zip exception.
    Write-Log "Restarting Cache..."
    $LASTEXITCODE = 0
    & $ccontrol start CACHE
    if ($LASTEXITCODE -ne 0) {
        $cacheRestartError = "ccontrol failed to start Cache (exit code $LASTEXITCODE). Please start it manually."
        Write-Log "ERROR: $cacheRestartError"
    } else {
        $waited = 0
        while (-not (Get-Process -Name "cache" -ErrorAction SilentlyContinue) -and $waited -lt 60) {
            Start-Sleep -Seconds 5; $waited += 5
            Write-Log "Waiting for Cache to start... ($waited s)"
        }
        if (-not (Get-Process -Name "cache" -ErrorAction SilentlyContinue)) {
            $cacheRestartError = "Cache did not start in time. Please start it manually."
            Write-Log "ERROR: $cacheRestartError"
        } else {
            Write-Log "Cache restarted successfully."
        }
    }
}

# Deferred throw: only reached when no zip exception propagated; surfaces the
# restart failure as a proper terminating error rather than a silent log line.
if ($cacheRestartError) { throw $cacheRestartError }
