@echo off
REM This batch file runs the PowerShell download script with execution policy bypass.
REM Usage: download_latest_blob.bat <ContainerName> <StorageAccountName>
REM   ContainerName      - Name of the Azure Storage container
REM   StorageAccountName - Name of the Azure Storage Account

if "%~2"=="" (
    echo Usage: download_latest_blob.bat ^<ContainerName^> ^<StorageAccountName^>
    exit /b 1
)

set CONTAINER_NAME=%~1
set STORAGE_ACCOUNT=%~2
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0download_latest_blob.ps1" -ContainerName "%CONTAINER_NAME%" -StorageAccountName "%STORAGE_ACCOUNT%"
