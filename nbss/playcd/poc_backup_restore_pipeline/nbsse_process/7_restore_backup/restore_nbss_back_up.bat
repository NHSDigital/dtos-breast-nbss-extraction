@echo off
REM This batch file runs the PowerShell restore script with execution policy bypass
REM Users can simply run this file without needing to unblock or configure anything
REM pushd handles UNC paths by mapping them to a temporary drive letter

pushd "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0restore_nbss_back_up.ps1" %*
popd
