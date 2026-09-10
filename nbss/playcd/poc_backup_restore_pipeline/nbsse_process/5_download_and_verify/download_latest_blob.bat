@echo off
REM This batch file runs the PowerShell download-and-verify script with execution policy bypass.
REM Usage: download_latest_blob.bat <ContainerName> <StorageAccountName> [KeyVaultName]
REM   ContainerName      - Name of the Azure Storage container
REM   StorageAccountName - Name of the Azure Storage Account
REM   KeyVaultName       - (optional) Name of the Azure Key Vault (default: nbsse-dev-kv)
REM
REM Examples:
REM   download_latest_blob.bat bso-001-container bsrtestdatalake
REM   download_latest_blob.bat bso-001-container bsrtestdatalake my-other-kv

if "%~2"=="" (
    echo Usage: download_latest_blob.bat ^<ContainerName^> ^<StorageAccountName^> [KeyVaultName]
    exit /b 1
)

set CONTAINER_NAME=%~1
set STORAGE_ACCOUNT=%~2
set KEY_VAULT=%~3

if "%KEY_VAULT%"=="" (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0download_latest_blob.ps1" -ContainerName "%CONTAINER_NAME%" -StorageAccountName "%STORAGE_ACCOUNT%"
) else (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0download_latest_blob.ps1" -ContainerName "%CONTAINER_NAME%" -StorageAccountName "%STORAGE_ACCOUNT%" -KeyVaultName "%KEY_VAULT%"
)
