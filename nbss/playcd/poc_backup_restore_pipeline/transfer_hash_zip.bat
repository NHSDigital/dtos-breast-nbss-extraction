@echo off
REM This batch file runs the PowerShell hash-and-store script with execution policy bypass.
REM Usage: transfer_hash_zip.bat <BsoCode> [ZipPath]
REM   BsoCode  - BSO code embedded in the Key Vault secret name  e.g. A0001344
REM   ZipPath  - (optional) full path to the zip file to hash
REM
REM Examples:
REM   transfer_hash_zip.bat A0001344
REM   transfer_hash_zip.bat A0001344 "C:\Backups\backup.zip"

if "%~1"=="" (
    echo Usage: transfer_hash_zip.bat ^<BsoCode^> [ZipPath]
    exit /b 1
)

set BSO_CODE=%~1
set ZIP_PATH=%~2

if "%ZIP_PATH%"=="" (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0transfer_hash_zip.ps1" -BsoCode "%BSO_CODE%"
) else (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0transfer_hash_zip.ps1" -BsoCode "%BSO_CODE%" -ZipPath "%ZIP_PATH%"
)
