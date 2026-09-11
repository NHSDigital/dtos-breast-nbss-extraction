@echo off
REM This batch file runs the PowerShell AzCopy install script with execution policy bypass
REM Users can simply run this file without needing to unblock or configure anything

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install_azcopy.ps1" %*
