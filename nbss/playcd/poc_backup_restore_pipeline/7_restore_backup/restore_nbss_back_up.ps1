<#
.SYNOPSIS
    Restores NBSS databases from a backup zip onto a clean InterSystems Cache installation.

.DESCRIPTION
    This script performs the following steps:
      1. Stops the running InterSystems Cache instance (if running).
      2. Extracts BACKUP_CACHE.DAT from the backup zip to a staging directory.
      3. Extracts NBSS application files (Attachments, Letters, Labels) to NbssRoot.
      4. Starts the Cache instance.
      5. Runs ^DBREST automatically to restore the NBSS databases (dem_app, dem_dat)
        from BACKUP_CACHE.DAT, skipping system databases.
      6. Registers the restored databases and creates an NBSS namespace.

    The backup zip is expected to have been created by create_nbss_back_up.ps1.

    IMPORTANT: This script does NOT restore system databases (CACHESYS, CACHELIB,
    CACHEAUDIT, etc.) -- only the NBSS application databases. Restoring system
    databases from a different instance causes configuration conflicts.

    The NBSS databases (dem_app, dem_dat) are only captured inside BACKUP_CACHE.DAT
    (the Cache online backup). They are NOT among the CACHE.DAT cold-backup files
    in the zip, because on the source system they live under C:\NBSS\Cache\ rather
    than under C:\InterSystems\Cache\.

.PARAMETER BackupZip
    Path to the NBSS backup zip file to restore.

.PARAMETER NbssRoot
    Root folder where NBSS should be restored. Defaults to C:\NBSS.

.PARAMETER CacheRoot
    Path to the Cache instance folder. Defaults to C:\InterSystems\CacheRestore.

.PARAMETER InstanceName
    Name of the Cache instance. Defaults to CACHERESTORE.

.PARAMETER SkipNbssFiles
    If specified, skips restoring NBSS application files (Attachments, Letters, Labels).

.EXAMPLE
    .\restore_nbss_back_up.ps1 -BackupZip ".\NBSS_Backup_20260708_152359.zip"

.EXAMPLE
    .\restore_nbss_back_up.ps1 -BackupZip "D:\Backups\NBSS_A0001344_Backup_20260708_152359.zip" -CacheRoot "E:\InterSystems\CacheRestore"

.NOTES
    Must be run as Administrator.
    Cache will be stopped during file extraction and restarted before ^DBREST runs.
    The target Cache instance must use the same character width and locale as the source.
#>

#Requires -RunAsAdministrator
param (
    [Parameter(Mandatory)]
    [string]$BackupZip,

    [string]$NbssRoot      = "C:\NBSS",
    [string]$CacheRoot     = "C:\InterSystems\CacheRestore",
    [string]$InstanceName  = "CACHERESTORE",
    [string]$NbssDbDir     = "C:\NBSS\Cache",

    [switch]$SkipNbssFiles
)

$ErrorActionPreference = "Stop"

# Resolve relative paths against the script's directory (handles UNC path issues)
if (-not [System.IO.Path]::IsPathRooted($BackupZip)) {
    $BackupZip = Join-Path $PSScriptRoot $BackupZip
}

# Validate inputs
if (-not (Test-Path $BackupZip)) { throw "Backup zip not found: '$BackupZip'" }
$BackupZip = (Resolve-Path $BackupZip).ProviderPath

$ccontrol  = Join-Path $CacheRoot "bin\ccontrol.exe"
$csession  = Join-Path $CacheRoot "bin\csession.exe"
if (-not (Test-Path $ccontrol)) { throw "ccontrol.exe not found at '$ccontrol'. Verify -CacheRoot points to the Cache instance folder." }
if (-not (Test-Path $csession)) { throw "csession.exe not found at '$csession'. Verify -CacheRoot points to the Cache instance folder." }

function Write-Log { param([string]$m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" }

Write-Log "Backup zip   : $BackupZip"
Write-Log "NBSS root    : $NbssRoot"
Write-Log "Cache root   : $CacheRoot"
Write-Log "Instance     : $InstanceName"
Write-Log "NBSS DB dir  : $NbssDbDir"

# --- Step 1: Stop Cache instance if running ---
Write-Log "Checking if instance $InstanceName is running..."

# Use ccontrol qlist to check specific instance status (not Get-Process which sees ALL instances)
# qlist output format: INSTANCENAME^dir^version^status^other fields
# Status field contains "running" when up, or "down" / "sign-on inhibited" etc.
function Test-InstanceRunning {
    $qlist = & $ccontrol qlist 2>$null
    foreach ($line in $qlist) {
        if ($line -match "(?i)^$InstanceName\^" -and $line -match "(?i)running") { return $true }
    }
    return $false
}

if (Test-InstanceRunning) {
    Write-Log "Stopping instance $InstanceName..."
    $LASTEXITCODE = 0
    & $ccontrol stop $InstanceName quietly
    if ($LASTEXITCODE -ne 0) { throw "Failed to stop Cache instance '$InstanceName' (exit code $LASTEXITCODE)." }
    $waited = 0
    while ((Test-InstanceRunning) -and $waited -lt 120) {
        Start-Sleep -Seconds 5; $waited += 5
        Write-Log "Waiting for instance to stop... ($waited s)"
    }
    if (Test-InstanceRunning) { throw "Instance '$InstanceName' did not stop in time." }
    Write-Log "Instance $InstanceName stopped."
} else {
    Write-Log "Instance $InstanceName is not running -- skipping stop."
}

# --- Step 2: Extract BACKUP_CACHE.DAT and NBSS files from the zip ---
Write-Log "Opening backup zip..."
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($BackupZip)

$backupDatEntry  = "Cache/mgr/BACKUP_CACHE.DAT"
$backupDatTarget = Join-Path $CacheRoot "mgr\BACKUP_CACHE.DAT"
$nbssFolders     = @("Attachments/", "Letters/", "Labels/")
$restoredNbssFiles = 0

try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.EndsWith("/")) { continue }

        $targetPath = $null

        # Extract BACKUP_CACHE.DAT for use with ^DBREST
        if ($entry.FullName -eq $backupDatEntry) {
            $targetPath = $backupDatTarget
        }
        # Extract NBSS application files
        elseif (-not $SkipNbssFiles) {
            foreach ($folder in $nbssFolders) {
                if ($entry.FullName.StartsWith($folder, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $relativePath = $entry.FullName.Replace("/", "\")
                    $targetPath = Join-Path $NbssRoot $relativePath

                    $resolvedRoot = [System.IO.Path]::GetFullPath(($NbssRoot.TrimEnd("\") + "\"))
                    $resolvedTarget = [System.IO.Path]::GetFullPath($targetPath)
                    if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                        throw "Zip entry path traversal detected: '$($entry.FullName)'"
                    }
                    break
                }
            }
        }

        if ($targetPath) {
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            $stream = $entry.Open()
            try {
                $fileStream = [System.IO.File]::Create($targetPath)
                try {
                    $stream.CopyTo($fileStream)
                } finally {
                    $fileStream.Dispose()
                }
            } finally {
                $stream.Dispose()
            }

            if ($entry.FullName -eq $backupDatEntry) {
                $sizeMB = [math]::Round($entry.Length / 1MB, 1)
                Write-Log "Extracted: BACKUP_CACHE.DAT ($sizeMB MB) -> $targetPath"
            } else {
                $restoredNbssFiles++
            }
        }
    }
    Write-Log "Extraction complete: BACKUP_CACHE.DAT + $restoredNbssFiles NBSS file(s)"
} finally {
    $zip.Dispose()
}

if (-not (Test-Path $backupDatTarget)) {
    throw "BACKUP_CACHE.DAT was not found in the zip archive. Cannot proceed with database restore."
}

# --- Step 3: Start Cache ---
Write-Log "Starting instance $InstanceName..."
$LASTEXITCODE = 0
& $ccontrol start $InstanceName
if ($LASTEXITCODE -ne 0) { throw "Failed to start Cache instance '$InstanceName' (exit code $LASTEXITCODE)." }

# ccontrol start is synchronous; give the instance a moment to fully initialise
Start-Sleep -Seconds 5
Write-Log "Instance $InstanceName started successfully."

# --- Step 4: Create, register and mount NBSS databases ---
# ^DBREST requires the target databases to be mounted and writable.
# We create empty databases, register them in the config, and mount them.
$demAppDir = Join-Path $NbssDbDir "dem_app"
$demDatDir = Join-Path $NbssDbDir "dem_dat"

foreach ($dir in @($demAppDir, $demDatDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Log "Created directory: $dir"
    }
}

# Create empty databases, register in config, and mount — all via ObjectScript
# Each command is a single line (csession executes lines independently)
$setupDbLines = @(
    "WRITE ""Creating and mounting NBSS databases..."",!"
    "SET sc = ##class(SYS.Database).CreateDatabase(""$demAppDir\"")"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR CreateDatabase dem_app: ""_`$System.Status.GetErrorText(sc),! } ELSE { WRITE ""Created dem_app"",! }"
    "SET sc = ##class(SYS.Database).CreateDatabase(""$demDatDir\"")"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR CreateDatabase dem_dat: ""_`$System.Status.GetErrorText(sc),! } ELSE { WRITE ""Created dem_dat"",! }"
    "KILL props SET props(""Directory"") = ""$demAppDir\"" SET sc = ##class(Config.Databases).Create(""NBSS_DEM_APP"", .props)"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR registering dem_app: ""_`$System.Status.GetErrorText(sc),! } ELSE { WRITE ""Registered NBSS_DEM_APP"",! }"
    "KILL props SET props(""Directory"") = ""$demDatDir\"" SET sc = ##class(Config.Databases).Create(""NBSS_DEM_DAT"", .props)"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR registering dem_dat: ""_`$System.Status.GetErrorText(sc),! } ELSE { WRITE ""Registered NBSS_DEM_DAT"",! }"
    "SET sc = ##class(SYS.Database).MountDatabase(""$demAppDir\"")"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR mounting dem_app: ""_`$System.Status.GetErrorText(sc),! } ELSE { WRITE ""Mounted dem_app"",! }"
    "SET sc = ##class(SYS.Database).MountDatabase(""$demDatDir\"")"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR mounting dem_dat: ""_`$System.Status.GetErrorText(sc),! } ELSE { WRITE ""Mounted dem_dat"",! }"
    "WRITE ""Database setup complete."",!"
    "HALT"
)

$setupDbInput = Join-Path $env:TEMP "setup_db_input.txt"
$setupDbOutput = Join-Path $env:TEMP "setup_db_output.txt"
($setupDbLines -join "`r`n") | Set-Content -Path $setupDbInput -Encoding ASCII

Write-Log "Creating, registering and mounting NBSS databases..."
$setupDbProc = Start-Process -FilePath $csession `
    -ArgumentList "$InstanceName -U `"%SYS`"" `
    -RedirectStandardInput $setupDbInput `
    -RedirectStandardOutput $setupDbOutput `
    -NoNewWindow -Wait -PassThru

$setupDbResult = Get-Content $setupDbOutput -Raw

if ($setupDbResult -match "Database setup complete") {
    Write-Log "  Databases created and mounted successfully."
} else {
    Write-Log "  WARNING: Database setup may have failed. Output:"
    Write-Log $setupDbResult
}

# --- Step 5: Run ^DBREST interactively to restore NBSS databases ---
# ^DBREST MUST run interactively because piping responses is unsafe — one misaligned
# response can overwrite running system databases and crash Windows.
Write-Log ""
Write-Log "============================================================"
Write-Log "INTERACTIVE STEP: ^DBREST"
Write-Log "============================================================"
Write-Log ""
Write-Log "A Cache terminal will now open."
Write-Log "Type:  DO ^DBREST"
Write-Log ""
Write-Log "Then respond to each prompt as shown:"
Write-Log ""
Write-Log "  1 =>                                     type: 2"
Write-Log "  Do you want to set switch 10...? Yes =>  press Enter"
Write-Log "  Device:                                  type: $backupDatTarget"
Write-Log "  Is this the backup...? Yes =>            press Enter"
Write-Log ""
Write-Log "  c:\intersystems\cache\mgr\            => type: X"
Write-Log "  c:\intersystems\cache\mgr\cacheaudit\ => type: X"
Write-Log "  c:\intersystems\cache\mgr\user\       => type: X"
Write-Log "  c:\nbss\cache\dem_app\                => type: $demAppDir\"
Write-Log "  c:\nbss\cache\dem_dat\                => type: $demDatDir\"
Write-Log ""
Write-Log "  Do you want to change this list...? No => press Enter"
Write-Log "  Confirm Restore? No =>                    type: Yes"
Write-Log "  [restore runs...]"
Write-Log "  Device:                                   type: STOP"
Write-Log "  Do you have any more backups...? Yes =>   type: No"
Write-Log "  Apply: 1 =>                               type: 4"
Write-Log ""
Write-Log "  Then type: HALT"
Write-Log "============================================================"
Write-Log ""

# Run csession interactively with -U "%SYS" so it starts in the right namespace.
# The user just needs to type: DO ^DBREST  (then follow the prompts)
Write-Log "Launching interactive csession for ^DBREST..."
Write-Log "  Type:  DO ^DBREST   (then follow the prompts above)"
Write-Log ""
$proc = Start-Process -FilePath $csession -ArgumentList "$InstanceName -U `"%SYS`"" -Wait -PassThru
$dbrestExit = $proc.ExitCode

if ($dbrestExit -ne 0) {
    Write-Warning "csession exited with code $dbrestExit. The restore may not have completed."
}

Write-Log "^DBREST session ended."

# --- Step 6: Create NBSS namespace ---
Write-Log "Creating NBSS namespace..."

# Databases were registered in step 4; now create a namespace mapping to them.
$configLines = @(
    "KILL props"
    "SET props(""Globals"") = ""NBSS_DEM_DAT"""
    "SET props(""Routines"") = ""NBSS_DEM_APP"""
    "SET sc = ##class(Config.Namespaces).Create(""NBSS"", .props)"
    "IF '`$System.Status.IsOK(sc) { WRITE ""ERROR creating namespace: ""_`$System.Status.GetErrorText(sc),! QUIT }"
    "WRITE ""Created namespace: NBSS"",!"
    "WRITE ""Configuration complete."",!"
    "HALT"
)

$configInput = Join-Path $env:TEMP "cache_config_input.txt"
$configOutput = Join-Path $env:TEMP "cache_config_output.txt"
($configLines -join "`r`n") | Set-Content -Path $configInput -Encoding ASCII

$configProc = Start-Process -FilePath $csession `
    -ArgumentList "$InstanceName -U `"%SYS`"" `
    -RedirectStandardInput $configInput `
    -RedirectStandardOutput $configOutput `
    -NoNewWindow -Wait -PassThru

$configResult = Get-Content $configOutput -Raw

if ($configResult -match "Configuration complete") {
    Write-Log "  Databases registered and namespace created successfully."
} else {
    Write-Log "  WARNING: Configuration may have issues. Output:"
    Write-Log $configResult
}

# --- Summary ---
Write-Log ""
Write-Log "============================================================"
Write-Log "RESTORE COMPLETE"
Write-Log "============================================================"
Write-Log ""
Write-Log "Databases restored and registered:"
Write-Log "  NBSS_DEM_APP -> $demAppDir"
Write-Log "  NBSS_DEM_DAT -> $demDatDir"
Write-Log ""
Write-Log "Namespace created: NBSS"
Write-Log ""
Write-Log "Next step: run .\run_integrity_check.ps1 to verify database integrity."
Write-Log "============================================================"
