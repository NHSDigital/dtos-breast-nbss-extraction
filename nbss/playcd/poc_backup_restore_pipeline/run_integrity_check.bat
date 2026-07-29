@echo off
REM This batch file runs the PowerShell integrity check script with execution policy bypass
REM Users can simply run this file without needing to unblock or configure anything

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0run_integrity_check.ps1" %*
