<#
.SYNOPSIS
    Runs a structural integrity check on the restored NBSS databases.

.DESCRIPTION
    Calls Silent^Integrity on the NBSS dem_app and dem_dat databases and waits
    for the results. Use this after a restore to verify the databases are intact,
    or at any time to re-check integrity.

.PARAMETER CacheRoot
    Path to the Cache instance folder. Defaults to C:\InterSystems\CacheRestore.

.PARAMETER InstanceName
    Name of the Cache instance. Defaults to CACHERESTORE.

.PARAMETER NbssDbDir
    Root directory containing the NBSS databases. Defaults to C:\NBSS\Cache.

.PARAMETER TimeoutSeconds
    Maximum time to wait for the integrity check to complete. Defaults to 600 (10 minutes).

.EXAMPLE
    .\run_integrity_check.ps1

.EXAMPLE
    .\run_integrity_check.ps1 -CacheRoot "E:\InterSystems\CacheRestore" -TimeoutSeconds 900

.NOTES
    Must be run as Administrator.
    The Cache instance must be running.
#>

#Requires -RunAsAdministrator
param (
    [string]$CacheRoot     = "C:\InterSystems\CacheRestore",
    [string]$InstanceName  = "CACHERESTORE",
    [string]$NbssDbDir     = "C:\NBSS\Cache",
    [int]$TimeoutSeconds   = 600
)

$ErrorActionPreference = "Stop"

$csession = Join-Path $CacheRoot "bin\csession.exe"
if (-not (Test-Path $csession)) { throw "csession.exe not found at '$csession'. Verify -CacheRoot." }

$demAppDir = Join-Path $NbssDbDir "dem_app"
$demDatDir = Join-Path $NbssDbDir "dem_dat"

function Write-Log { param([string]$m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" }

Write-Log "NBSS Database Integrity Check"
Write-Log "=============================="
Write-Log "Instance   : $InstanceName"
Write-Log "Databases  : $demAppDir, $demDatDir"
Write-Log ""

$integLogFile = Join-Path $CacheRoot "mgr\integ_nbss.txt"

# Remove previous log so we can detect when the new one is written
if (Test-Path $integLogFile) {
    Remove-Item $integLogFile -Force
    Write-Log "Removed previous integrity log."
}

# Launch Silent^Integrity
$integrityLines = @(
    "SET dirlist = `$LISTBUILD(""$demAppDir\"", ""$demDatDir\"")"
    "DO Silent^Integrity(""$integLogFile"", dirlist)"
    "WRITE ""Integrity check launched."",!"
    "HALT"
)

$integrityInput = Join-Path $env:TEMP "integrity_check_input.txt"
$integrityOutput = Join-Path $env:TEMP "integrity_check_output.txt"
($integrityLines -join "`r`n") | Set-Content -Path $integrityInput -Encoding ASCII

Write-Log "Launching integrity check (background process in Cache)..."
$proc = Start-Process -FilePath $csession `
    -ArgumentList "$InstanceName -U `"%SYS`"" `
    -RedirectStandardInput $integrityInput `
    -RedirectStandardOutput $integrityOutput `
    -NoNewWindow -Wait -PassThru

$launchResult = Get-Content $integrityOutput -Raw
if ($launchResult -match "Integrity check launched") {
    Write-Log "Integrity check started successfully."
} else {
    Write-Log "WARNING: Unexpected output from launch:"
    Write-Log $launchResult
}

# Poll for completion
Write-Log "Waiting for integrity check to complete (timeout: ${TimeoutSeconds}s)..."
$waited = 0

while ($waited -lt $TimeoutSeconds) {
    Start-Sleep -Seconds 5
    $waited += 5

    if (Test-Path $integLogFile) {
        $logContent = Get-Content $integLogFile -Raw -ErrorAction SilentlyContinue

        # Treat the check as complete only once we have a summary block for each directory
        $summaryPattern = "(?ms)---Total for directory .+?(?:No Errors were found in this directory\.|errors? (?:found|exposed).*)"
        if ([regex]::Matches($logContent, $summaryPattern).Count -ge 2) {
            break
        }
    }

    if ($waited % 30 -eq 0) {
        Write-Log "  Still running... ($waited s elapsed)"
    }
}

Write-Log ""

if ($waited -ge $TimeoutSeconds) {
    Write-Log "WARNING: Integrity check did not complete within $TimeoutSeconds seconds."
    Write-Log "Check the log manually: $integLogFile"
    exit 1
}

# Display results
Write-Log "=============================="
Write-Log "INTEGRITY CHECK COMPLETE"
Write-Log "=============================="
Write-Log ""

# Show only the summary sections (totals per directory + error status)
$logContent = Get-Content $integLogFile -Raw
$summaryPattern = "(?ms)(---Total for directory .+?(?:No Errors were found in this directory\.|errors? (?:found|exposed).*))"
$summaries = [regex]::Matches($logContent, $summaryPattern)

if ($summaries.Count -gt 0) {
    foreach ($summary in $summaries) {
        Write-Host $summary.Value
        Write-Host ""
    }
} else {
    # Fallback: show full log if summary pattern doesn't match
    Write-Host $logContent
}

Write-Log ""

$errorsExposedMatch = [regex]::Match($logContent, "(?i)(\d+)\s+errors?\s+exposed")
$globalsWithErrorsMatch = [regex]::Match($logContent, "(?i)(\d+)\s+globals?\s+with\s+errors\s+found")

$errorsExposed = if ($errorsExposedMatch.Success) { [int]$errorsExposedMatch.Groups[1].Value } else { 0 }
$globalsWithErrors = if ($globalsWithErrorsMatch.Success) { [int]$globalsWithErrorsMatch.Groups[1].Value } else { 0 }

if ($errorsExposed -gt 0 -or $globalsWithErrors -gt 0) {
    Write-Log "RESULT: ERRORS DETECTED"
    Write-Warning "Integrity errors found — review $integLogFile before using this database."
    exit 2
} else {
    Write-Log "RESULT: ALL CHECKS PASSED — no errors found."
    exit 0
}
