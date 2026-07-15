@echo off
REM Wrapper to run install_cache_silent.ps1 bypassing ExecutionPolicy restrictions.
REM Pass all arguments through to the PowerShell script.
REM Must be run as Administrator.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0install_cache_silent.ps1" %*
