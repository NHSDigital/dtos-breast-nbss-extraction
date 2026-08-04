@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0generate-container-sas-token.ps1" %*
