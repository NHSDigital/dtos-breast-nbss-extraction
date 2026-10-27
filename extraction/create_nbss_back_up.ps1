<#
.SYNOPSIS
    Creates a timestamped zip backup of NBSS folders and InterSystems Caché database files.

.DESCRIPTION
    This script performs the following steps:
      1. Stops the running InterSystems Caché instance.
      2. Creates a zip archive containing the items listed in the manifest
        (default: backup_manifest.json next to this script).
      3. Saves the zip to the folder containing this script, named:
            {YYYYMMDD}-{BsoCode}.zip
      4. Restarts the Caché instance once the zip is complete.

    Use the -NbssRoot and -CacheRoot parameters if NBSS or InterSystems
    are installed on a different drive to the default (C:\).

.PARAMETER BsoCode
    BSO code to embed in the backup filename  e.g. A0001344.
    Defaults to "A000".

.PARAMETER NbssRoot
    Root folder where NBSS is installed. Defaults to C:\NBSS.

.PARAMETER CacheRoot
    Root folder where InterSystems is installed. Defaults to C:\InterSystems.

.PARAMETER ManifestPath
    JSON manifest listing what to back up. Each item has "root" ("Nbss" or "Cache")
    and "path" (a file or folder relative to that root; folders are added recursively).
    An item may instead have "anyOf": a list of {root, path} alternatives; the first
    one that exists is backed up.
    Defaults to backup_manifest.json in the script folder.

.EXAMPLE
    # Run with defaults (both on C:\)
    .\create_nbss_back_up.ps1 -BsoCode "A0001344"

.EXAMPLE
    # NBSS on D:\ and InterSystems on E:\
    .\create_nbss_back_up.ps1 -BsoCode "A0001344" -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"

.EXAMPLE
    # Only NBSS is on a different drive
    .\create_nbss_back_up.ps1 -BsoCode "A0001344" -NbssRoot "D:\NBSS"

.NOTES
    Must be run as Administrator.
    Caché will be stopped during the backup and restarted automatically on completion.
#>

#Requires -RunAsAdministrator
param (
    # BSO code to embed in the backup filename  e.g. A0001344
    [string]$BsoCode    = "A000",
    # Root path where NBSS is installed  e.g. C:\NBSS or D:\NBSS
    [string]$NbssRoot   = "C:\NBSS",
    # Root path where InterSystems Cache is installed  e.g. C:\InterSystems or D:\InterSystems
    [string]$CacheRoot  = "C:\InterSystems",
    # JSON manifest of items to back up
    [string]$ManifestPath = (Join-Path $PSScriptRoot "backup_manifest.json")
)

$ErrorActionPreference = "Stop"

# Derived paths from parameters
$ccontrol  = Join-Path $CacheRoot "Cache\bin\ccontrol.exe"

if (-not (Test-Path $ccontrol)) { throw "ccontrol.exe not found at '$ccontrol'. Verify -CacheRoot." }
if (-not (Test-Path $ManifestPath)) { throw "Manifest not found at '$ManifestPath'." }

# Validate the manifest before Cache is stopped
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if (-not $manifest.items) { throw "Manifest '$ManifestPath' has no 'items'." }
$roots = @{ Nbss = $NbssRoot; Cache = $CacheRoot }
# Each item becomes a list of candidate locations; the first that exists is used
$items = foreach ($item in $manifest.items) {
    $candidates = @(if ($item.anyOf) { $item.anyOf } else { $item })
    foreach ($c in $candidates) {
        if (-not $c.path -or -not $roots.ContainsKey([string]$c.root)) {
            throw "Invalid manifest entry (root must be 'Nbss' or 'Cache', path required): $($c | ConvertTo-Json -Compress)"
        }
    }
    , $candidates
}

$timestamp = Get-Date -Format "yyyyMMdd"
$zipPath   = Join-Path $PSScriptRoot "${timestamp}-${BsoCode}.zip"

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
        # Entry names are the path relative to the item's root
        foreach ($candidates in $items) {
            $full = $null
            foreach ($c in $candidates) {
                $root = $roots[[string]$c.root].TrimEnd('\')
                $candidate = Join-Path $root $c.path
                if (Test-Path $candidate) { $full = $candidate; break }
            }
            if (-not $full) {
                Write-Log "Skipping (not found): $(($candidates | ForEach-Object { Join-Path $roots[[string]$_.root] $_.path }) -join ' | ')"
                continue
            }

            $files = if (Test-Path $full -PathType Container) { Get-ChildItem $full -Recurse -File } else { Get-Item $full }
            foreach ($file in $files) {
                $entry = $file.FullName.Substring($root.Length + 1).Replace("\","/")
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry, 'Optimal') | Out-Null
            }
            Write-Log "Added: $full"
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
