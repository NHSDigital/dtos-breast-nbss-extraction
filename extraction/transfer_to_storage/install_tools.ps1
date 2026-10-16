param(
    [string]$ToolVersionsFile = (Join-Path $PSScriptRoot 'tool_versions.json'),
    [string]$AzCopyInstallDir = (Join-Path $env:ProgramFiles 'AzCopy')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path -LiteralPath $ToolVersionsFile)) {
    throw "Tool versions file not found: $ToolVersionsFile"
}
$ToolVersions = Get-Content -LiteralPath $ToolVersionsFile -Raw | ConvertFrom-Json

function Assert-MicrosoftSignature {
    param([Parameter(Mandatory)][string]$Path)

    $sig = Get-AuthenticodeSignature -LiteralPath $Path
    $subject = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '<none>' }
    if ($sig.Status -ne 'Valid' -or $subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
        throw "Code signature check failed for $Path. Status: $($sig.Status). Signer: $subject"
    }
    Write-Host "Verified Microsoft signature on $(Split-Path -Leaf $Path)."
}

function Add-ToMachinePath {
    param([Parameter(Mandatory)][string]$Directory)

    $path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if (($path -split ';') -notcontains $Directory) {
        [Environment]::SetEnvironmentVariable('Path', "$path;$Directory", 'Machine')
    }
}

function Install-AzureCli {
    param([Parameter(Mandatory)]$Tool)

    $msi = Join-Path $env:TEMP 'azure-cli.msi'
    Write-Host "Downloading $($Tool.DisplayName) from $($Tool.Url) ..."
    Invoke-WebRequest -Uri $Tool.Url -OutFile $msi -UseBasicParsing
    Assert-MicrosoftSignature -Path $msi

    Write-Host "Installing $($Tool.DisplayName) ..."
    $proc = Start-Process -FilePath 'msiexec.exe' -Wait -PassThru `
        -ArgumentList @('/i', "`"$msi`"", '/qn', '/norestart')
    # 3010 = success, reboot required.
    if ($proc.ExitCode -notin 0, 3010) {
        throw "Azure CLI MSI install failed with exit code $($proc.ExitCode)."
    }
    Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
}

function Install-AzCopy {
    param([Parameter(Mandatory)]$Tool)

    $zip = Join-Path $env:TEMP 'azcopy.zip'
    $extractDir = Join-Path $env:TEMP 'azcopy'
    Write-Host "Downloading $($Tool.DisplayName) from $($Tool.Url) ..."
    Invoke-WebRequest -Uri $Tool.Url -OutFile $zip -UseBasicParsing

    Expand-Archive -LiteralPath $zip -DestinationPath $extractDir -Force
    $exe = Get-ChildItem -LiteralPath $extractDir -Recurse -Filter 'azcopy.exe' | Select-Object -First 1
    if (-not $exe) {
        throw 'azcopy.exe not found in the downloaded archive.'
    }
    # The zip itself is unsigned, so verify the executable inside it.
    Assert-MicrosoftSignature -Path $exe.FullName

    Write-Host "Installing $($Tool.DisplayName) to $AzCopyInstallDir ..."
    New-Item -ItemType Directory -Path $AzCopyInstallDir -Force | Out-Null
    Copy-Item -LiteralPath $exe.FullName -Destination $AzCopyInstallDir -Force
    Add-ToMachinePath -Directory $AzCopyInstallDir
    Remove-Item -LiteralPath $zip, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (Get-Command -Name 'az' -ErrorAction SilentlyContinue) {
    Write-Host 'Azure CLI is already installed. Leaving it unchanged.'
}
else {
    Install-AzureCli -Tool $ToolVersions.AzureCli
}

if (Get-Command -Name 'azcopy' -ErrorAction SilentlyContinue) {
    Write-Host 'AzCopy is already installed. Leaving it unchanged.'
}
else {
    Install-AzCopy -Tool $ToolVersions.AzCopy
}

# Reload PATH so tools installed above are visible in this session.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($cmd in 'az', 'azcopy') {
    if (-not (Get-Command -Name $cmd -ErrorAction SilentlyContinue)) {
        throw "'$cmd' is still not on PATH after installation."
    }
}

Write-Host 'All tools are installed. If run_azcopy.ps1 cannot find az or azcopy, open a new PowerShell window.'
