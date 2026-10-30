param(
    [Parameter(Mandatory)][string]$BsoName,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9]+$')][string]$BsoCode,
    [ValidatePattern('^[A-Za-z]$')][string]$NbssDrive = 'C',
    [ValidatePattern('^[A-Za-z]$')][string]$InterSystemsDrive = 'C'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$nbssRoot = "${NbssDrive}:\NBSS"
$cacheRoot = "${InterSystemsDrive}:\InterSystems"
$livDat = Join-Path $nbssRoot 'Cache\LIV_DAT'
$safeBsoName = $BsoName.Trim() -replace '[^A-Za-z0-9-]+', '_'
$zipPath = Join-Path $PSScriptRoot "$(Get-Date -Format 'yyyy-MM-dd')-$safeBsoName-$BsoCode.zip"

Write-Host "Searching for BACKUP*.DAT files in $nbssRoot and $cacheRoot ..."
$found = @(foreach ($root in $nbssRoot, $cacheRoot) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Filter 'BACKUP*.DAT' -File -Recurse -Force
    }
})
# Keep only the newest backup in each folder, e.g. BACKUP_CACHE.DAT over an older BACKUP_CACHE_1.DAT.
$backups = @($found | Group-Object DirectoryName | ForEach-Object {
    $_.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
})
foreach ($backup in $backups) {
    Write-Host "   $($backup.FullName) ($($backup.LastWriteTime))"
}

$latest = $backups | Where-Object { $_.DirectoryName -eq $livDat }
if (-not $latest) {
    throw "No BACKUP*.DAT file found in $livDat. Check -NbssDrive."
}
if ($latest.LastWriteTime -lt (Get-Date).AddDays(-300)) {
    throw "Latest backup in $livDat is more than a week old: $($latest.FullName) ($($latest.LastWriteTime))."
}

$files = $backups
foreach ($name in 'Attachments', 'Letters', 'Labels', 'Reports') {
    $folder = Join-Path $nbssRoot $name
    if (Test-Path -LiteralPath $folder) {
        $folderFiles = @(Get-ChildItem -LiteralPath $folder -File -Recurse -Force)
        Write-Host "Found $($folderFiles.Count) file(s) in $folder."
        $files += $folderFiles
    }
    else {
        Write-Warning "Folder not found, skipping: $folder"
    }
}

Write-Host "Creating $zipPath ..."
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    $manifest = foreach ($file in $files) {
        # Keep the folder structure from the file's own drive root, e.g. NBSS/Attachments/...
        $volumeRoot = [System.IO.Path]::GetPathRoot($file.FullName)
        $entryName = $file.FullName.Substring($volumeRoot.Length).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName, 'Optimal') | Out-Null
        [pscustomobject]@{
            Path             = $entryName
            SizeBytes        = $file.Length
            LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o')
        }
    }
    $writer = New-Object System.IO.StreamWriter($zip.CreateEntry('manifest.csv').Open())
    try {
        $manifest | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $writer.WriteLine($_) }
    }
    finally {
        $writer.Dispose()
    }
    $zip.Dispose()
}
catch {
    $zip.Dispose()
    # An incomplete zip is still a valid archive, so remove it to avoid it being uploaded.
    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $zipPath) {
        Write-Warning "Could not delete incomplete zip, delete it manually before uploading: $zipPath"
    }
    throw
}

$zipSize = (Get-Item -LiteralPath $zipPath).Length
$zipSizeGB = [math]::Round($zipSize / 1GB, 2)
if ($zipSize -ge 50GB) {
    Remove-Item -LiteralPath $zipPath -Force
    throw "Zip was $zipSizeGB GB, but must be under 50 GB. It has been deleted."
}

Write-Host "Created $zipPath ($zipSizeGB GB, $($files.Count) files)."
