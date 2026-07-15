<#
.SYNOPSIS
    Silently installs a clean InterSystems Caché instance and optionally restores an NBSS backup.

.DESCRIPTION
    This script performs a fully unattended Caché installation:
      1. Checks for port conflicts with existing Caché instances.
      2. Runs the Caché installer in silent mode using /instance and /qn flags.
      3. Starts the instance and provides connection information.
      4. Optionally restores an NBSS backup into the new instance.

    Designed to run alongside an existing NBSS/Caché installation without interference.

.PARAMETER InstallerPath
    Path to the Caché setup executable (setup_cache.exe or similar).

.PARAMETER InstallDir
    Target installation directory. Defaults to C:\InterSystems\CacheRestore.

.PARAMETER InstanceName
    Name for the new Caché instance. Defaults to CACHERESTORE.

.PARAMETER SuperServerPort
    TCP port for the Caché SuperServer. Defaults to 1973.
    The script will verify this port is not already in use.

.PARAMETER WebServerPort
    TCP port for the Caché private web server. Defaults to 57773.
    The script will verify this port is not already in use.

.PARAMETER BackupFile
    Optional path to a BACKUP_CACHE.DAT file to restore after installation.

.PARAMETER SkipRestore
    If set, skips the restore step even if BackupFile is provided.

.EXAMPLE
    # Install only (no restore)
    .\install_cache_silent.ps1 -InstallerPath "C:\Temp\cache-2018.1.4.505.1-win_x64.exe"

.EXAMPLE
    # Install and restore
    .\install_cache_silent.ps1 `
        -InstallerPath "C:\Temp\cache-2018.1.4.505.1-win_x64.exe" `
        -BackupFile "C:\Backups\BACKUP_CACHE.DAT"

.EXAMPLE
    # Custom ports to avoid conflicts
    .\install_cache_silent.ps1 `
        -InstallerPath "C:\Temp\cache-2018.1.4.505.1-win_x64.exe" `
        -SuperServerPort 1974 `
        -WebServerPort 57774

.NOTES
    Must be run as Administrator.
    Run this on the Windows machine (inside Parallels) where Caché will be installed.
    Ensure the Caché installer media is accessible from the VM.
#>

#Requires -RunAsAdministrator
param (
    [Parameter(Mandatory)]
    [string]$InstallerPath,

    [string]$InstallDir       = "C:\InterSystems\CacheRestore",
    [string]$InstanceName     = "CACHERESTORE",
    [int]$SuperServerPort     = 1973,
    [int]$WebServerPort       = 57773,
    [string]$BackupFile       = "",
    [switch]$SkipRestore
)

$ErrorActionPreference = "Stop"

function Write-Log { param([string]$m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" }

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if (-not (Test-Path $InstallerPath)) {
    throw "Installer not found at '$InstallerPath'. Provide the path to setup_cache.exe."
}

if ($BackupFile -and -not (Test-Path $BackupFile)) {
    throw "Backup file not found at '$BackupFile'."
}

# ---------------------------------------------------------------------------
# Port conflict checks
# ---------------------------------------------------------------------------

Write-Log "Checking for port conflicts..."

function Test-PortInUse {
    param([int]$Port)
    $listener = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq "Listen" }
    return ($null -ne $listener)
}

if (Test-PortInUse $SuperServerPort) {
    # Identify what's using the port
    $proc = Get-NetTCPConnection -LocalPort $SuperServerPort -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq "Listen" } |
            Select-Object -First 1
    $processName = (Get-Process -Id $proc.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    throw @"
SuperServer port $SuperServerPort is already in use by process '$processName' (PID $($proc.OwningProcess)).
This is likely your existing Caché/NBSS instance.
Use -SuperServerPort to specify a different port (e.g. -SuperServerPort 1974).
"@
}

if (Test-PortInUse $WebServerPort) {
    $proc = Get-NetTCPConnection -LocalPort $WebServerPort -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq "Listen" } |
            Select-Object -First 1
    $processName = (Get-Process -Id $proc.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    throw @"
Web server port $WebServerPort is already in use by process '$processName' (PID $($proc.OwningProcess)).
Use -WebServerPort to specify a different port (e.g. -WebServerPort 57774).
"@
}

Write-Log "Ports $SuperServerPort (SuperServer) and $WebServerPort (Web) are available."

# ---------------------------------------------------------------------------
# Check for existing instance with the same name
# ---------------------------------------------------------------------------

$ccontrolDefault = "C:\InterSystems\Cache\bin\ccontrol.exe"
if (Test-Path $ccontrolDefault) {
    $existingInstances = & $ccontrolDefault qlist 2>$null
    if ($existingInstances -match $InstanceName) {
        throw "A Caché instance named '$InstanceName' already exists. Use -InstanceName to choose a different name."
    }
}

# ---------------------------------------------------------------------------
# Run silent installer
# ---------------------------------------------------------------------------

Write-Log "Starting silent Caché installation..."
Write-Log "  Instance : $InstanceName"
Write-Log "  Directory: $InstallDir"
Write-Log "  Ports    : SuperServer=$SuperServerPort, Web=$WebServerPort"

# Per InterSystems docs, unattended install uses:
#   <installer>.exe /instance <name> /qn <PROPERTIES>
# /qn = completely silent (no UI). /qb = shows progress bar only.
$installerArgs = @(
    "/instance", $InstanceName
    "/qn"
    "INSTALLDIR=`"$InstallDir`""
    "SUPERSERVERPORT=$SuperServerPort"
    "WEBSERVERPORT=$WebServerPort"
    "INITIALSECURITY=None"
)

Write-Log "Command: $InstallerPath $($installerArgs -join ' ')"

$process = Start-Process -FilePath $InstallerPath `
  -ArgumentList $installerArgs `
  -Wait -PassThru

if ($process.ExitCode -ne 0) {
    throw "Caché installer exited with code $($process.ExitCode). Check the installer log in $InstallDir\mgr\cconsole.log"
}

Write-Log "Installation completed successfully."

# ---------------------------------------------------------------------------
# Start instance
# ---------------------------------------------------------------------------

$ccontrolNew = Join-Path $InstallDir "bin\ccontrol.exe"
$csessionNew = Join-Path $InstallDir "bin\csession.exe"

if (-not (Test-Path $ccontrolNew)) {
    throw "ccontrol.exe not found at '$ccontrolNew'. Installation may have failed."
}

Write-Log "Starting instance $InstanceName..."
& $ccontrolNew start $InstanceName

Write-Log "  Management Portal: http://localhost:$WebServerPort/csp/sys/UtilHome.csp"
Write-Log "  Terminal: csession $InstanceName"

# ---------------------------------------------------------------------------
# Restore backup (optional)
# ---------------------------------------------------------------------------

if ($BackupFile -and -not $SkipRestore) {
    Write-Log "Restoring backup from: $BackupFile"

    # The restore feeds commands into csession interactively via ^DBREST.
    # ^DBREST prompts: Device (backup file path), Is this a clustered restore? (No), Restore all? (Yes)
    $restoreScript = @"
ZN "%SYS"
DO ^DBREST

$($BackupFile)

No
Yes
"@

    Write-Log 'Running restore via csession (this may take several minutes)...'
    $restoreScript | & $csessionNew $InstanceName -U "%SYS"

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Restore process returned exit code $LASTEXITCODE. Check the terminal output above."
    } else {
        Write-Log "Restore completed successfully."
    }
} elseif ($BackupFile -and $SkipRestore) {
    Write-Log "Backup file provided but -SkipRestore was set. Skipping restore."
} else {
    Write-Log "No backup file provided. Instance is ready for manual restore."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Log ""
Write-Log "=== Installation Summary ==="
Write-Log "  Instance Name   : $InstanceName"
Write-Log "  Install Dir     : $InstallDir"
Write-Log "  SuperServer Port: $SuperServerPort"
Write-Log "  Web Server Port : $WebServerPort"
Write-Log "  Default User    : _SYSTEM"
Write-Log "  ccontrol        : $ccontrolNew"
Write-Log "  csession        : $csessionNew"
Write-Log ""
Write-Log "To connect:  csession $($InstanceName)"
Write-Log "To stop:     ccontrol stop $($InstanceName)"
Write-Log "To start:    ccontrol start $($InstanceName)"
