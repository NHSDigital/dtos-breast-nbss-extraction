@echo off
REM This batch file runs the PowerShell backup script with execution policy bypass
REM Users can simply run this file without needing to unblock or configure anything

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0create_nbss_back_up.ps1" %*
