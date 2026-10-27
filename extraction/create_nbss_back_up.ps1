<#
.SYNOPSIS
    Creates a timestamped zip backup of NBSS folders and InterSystems Caché database files.

.DESCRIPTION
    This script performs the following steps:
      1. Stops the running InterSystems Caché instance.
      2. Creates a zip archive containing the items listed in the config file
        (default: backup_config.json next to this script).
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

.PARAMETER Instance
    Name of the instance to stop and restart, which is also its folder under -CacheRoot
    (e.g. CACHE or CACHE202610V2). Optional when only one instance is installed.

.PARAMETER ConfigPath
    JSON config listing what to back up. Roots are named folders and can have any name:
    "Nbss" and "Cache" come from -NbssRoot and -CacheRoot, "Instance" is the selected instance
    folder, and more can be declared in the config "roots" object (name -> folder).
    Each item has "root" (a root name) and "path" (a file or folder relative to that root;
    folders are added recursively).
    An item may instead have "anyOf": a list of {root, path} alternatives; the first
    alternative that exists is backed up. Paths may contain wildcards (e.g. "Cache*/mgr").
    Add "latest": true to an item to pick the single newest match across all alternatives.
    Instead of "path", an entry can use "find" (a file name or list of names, exact match) to
    search recursively under root\path (path optional) regardless of folder layout.
    An item can also have "exclude": wildcard patterns matched against the full file path.
    Defaults to backup_config.json in the script folder.

.EXAMPLE
    # Run with defaults (both on C:\)
    .\create_nbss_back_up.ps1 -BsoCode "A0001344"

.EXAMPLE
    # NBSS on D:\ and InterSystems on E:\
    .\create_nbss_back_up.ps1 -BsoCode "A0001344" -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"

.EXAMPLE
    # Only NBSS is on a different drive
    .\create_nbss_back_up.ps1 -BsoCode "A0001344" -NbssRoot "D:\NBSS"

.EXAMPLE
    # Two instances installed under C:\InterSystems
    .\create_nbss_back_up.ps1 -BsoCode "A0001344" -Instance "CACHE202610V2"

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
    # Instance name / folder under CacheRoot  e.g. CACHE202610V2
    [string]$Instance   = "",
    # JSON config of items to back up
    [string]$ConfigPath = (Join-Path $PSScriptRoot "backup_config.json")
)

$ErrorActionPreference = "Stop"

# Locate the instance to stop; never guess when several are installed
$instDirs = @(Get-ChildItem -Path $CacheRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName 'bin\ccontrol.exe')) -or (Test-Path (Join-Path $_.FullName 'bin\iris.exe')) })
if ($Instance) { $instDirs = @($instDirs | Where-Object { $_.Name -eq $Instance }) }
if ($instDirs.Count -eq 0) { throw "No instance found under '$CacheRoot'$(if ($Instance) { " named '$Instance'" }). Verify -CacheRoot and -Instance." }
if ($instDirs.Count -gt 1) { throw "Several instances found under '$CacheRoot' ($($instDirs.Name -join ', ')). Specify -Instance." }
$instDir  = $instDirs[0].FullName
$instName = $instDirs[0].Name.ToUpper()
$ccontrol = @('bin\ccontrol.exe', 'bin\iris.exe') | ForEach-Object { Join-Path $instDir $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not (Test-Path $ConfigPath)) { throw "Config not found at '$ConfigPath'." }

# Validate the config before Cache is stopped
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if (-not $config.items) { throw "Config '$ConfigPath' has no 'items'." }
# Root names are free-form: config roots, then -NbssRoot/-CacheRoot
$roots = @{}
if ($config.roots) { foreach ($p in $config.roots.PSObject.Properties) { $roots[$p.Name] = [string]$p.Value } }
if ($PSBoundParameters.ContainsKey('NbssRoot')  -or -not $roots.ContainsKey('Nbss'))  { $roots['Nbss']  = $NbssRoot }
if ($PSBoundParameters.ContainsKey('CacheRoot') -or -not $roots.ContainsKey('Cache')) { $roots['Cache'] = $CacheRoot }
$roots['Instance'] = $instDir
# Each item becomes a list of candidate locations (paths may use wildcards)
$items = foreach ($item in $config.items) {
    $candidates = @(if ($item.anyOf) { $item.anyOf } else { $item })
    foreach ($c in $candidates) {
        if ((-not $c.path -and -not $c.find) -or -not $roots.ContainsKey([string]$c.root)) {
            throw "Invalid config entry (root must be one of: $($roots.Keys -join ', '); path or find required): $($c | ConvertTo-Json -Compress)"
        }
    }
    , [pscustomobject]@{ Latest = [bool]$item.latest; Exclude = @($item.exclude); Candidates = $candidates }
}

$timestamp = Get-Date -Format "yyyyMMdd"
$zipPath   = Join-Path $PSScriptRoot "${timestamp}-${BsoCode}.zip"

function Write-Log { param([string]$m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" }

# Only this instance's processes, so other running instances don't affect the waits
function Get-InstanceProcess {
    Get-Process -Name "cache", "irisdb" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$instDir\*" }
}

Write-Log "Instance    : $instName ($instDir)"

foreach ($k in $roots.Keys) { Write-Log ("Root {0}: {1}" -f $k, $roots[$k]) }

# Stop the instance
Write-Log "Stopping $instName..."
$LASTEXITCODE = 0
& $ccontrol stop $instName quietly
if ($LASTEXITCODE -ne 0) { throw "Failed to stop $instName (exit code $LASTEXITCODE). Check -CacheRoot and -Instance." }
$waited = 0
while ((Get-InstanceProcess) -and $waited -lt 60) {
    Start-Sleep -Seconds 5; $waited += 5
    Write-Log "Waiting... ($waited s)"
}
if (Get-InstanceProcess) { throw "$instName did not stop in time." }
Write-Log "$instName stopped."

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
        foreach ($item in $items) {
            $found = @(for ($i = 0; $i -lt $item.Candidates.Count; $i++) {
                $c = $item.Candidates[$i]
                $root = $roots[[string]$c.root].TrimEnd('\')
                if ($c.find) {
                    $base = if ($c.path) { Join-Path $root $c.path } else { $root }
                    foreach ($name in @($c.find)) {
                        Get-ChildItem -Path $base -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
                            ForEach-Object { [pscustomobject]@{ Index = $i; Root = $root; Item = $_ } }
                    }
                } else {
                    Get-Item -Path (Join-Path $root $c.path) -ErrorAction SilentlyContinue |
                        ForEach-Object { [pscustomobject]@{ Index = $i; Root = $root; Item = $_ } }
                }
            })
            if ($item.Exclude) {
                $found = @($found | Where-Object { $p = $_.Item.FullName; -not ($item.Exclude | Where-Object { $p -like $_ }) })
            }
            if (-not $found) {
                Write-Log "Skipping (not found): $(($item.Candidates | ForEach-Object { ('{0}\{1} {2}' -f $roots[[string]$_.root], $_.path, ($_.find -join ',')).Trim() }) -join ' | ')"
                continue
            }
            if ($item.Latest) {
                $found = @($found | Sort-Object { $_.Item.LastWriteTime } -Descending | Select-Object -First 1)
            } else {
                $firstIndex = $found[0].Index
                $found = @($found | Where-Object { $_.Index -eq $firstIndex })
            }

            foreach ($f in $found) {
                $files = if ($f.Item.PSIsContainer) { Get-ChildItem -LiteralPath $f.Item.FullName -Recurse -File } else { $f.Item }
                foreach ($file in $files) {
                    $entry = $file.FullName.Substring($f.Root.Length + 1).Replace("\","/")
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry, 'Optimal') | Out-Null
                }
                Write-Log "Added: $($f.Item.FullName)"
            }
        }
    } finally {
        $zip.Dispose()
    }

    Write-Log "Backup complete: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1MB,2)) MB)"
} finally {
    # Restart Caché — runs even if zip creation threw an exception.
    # Failures are recorded in $cacheRestartError and thrown after this block so
    # they do not suppress any in-flight zip exception.
    Write-Log "Restarting $instName..."
    $LASTEXITCODE = 0
    & $ccontrol start $instName
    if ($LASTEXITCODE -ne 0) {
        $cacheRestartError = "Failed to start $instName (exit code $LASTEXITCODE). Please start it manually."
        Write-Log "ERROR: $cacheRestartError"
    } else {
        $waited = 0
        while (-not (Get-InstanceProcess) -and $waited -lt 60) {
            Start-Sleep -Seconds 5; $waited += 5
            Write-Log "Waiting for $instName to start... ($waited s)"
        }
        if (-not (Get-InstanceProcess)) {
            $cacheRestartError = "$instName did not start in time. Please start it manually."
            Write-Log "ERROR: $cacheRestartError"
        } else {
            Write-Log "$instName restarted successfully."
        }
    }
}

# Deferred throw: only reached when no zip exception propagated; surfaces the
# restart failure as a proper terminating error rather than a silent log line.
if ($cacheRestartError) { throw $cacheRestartError }
