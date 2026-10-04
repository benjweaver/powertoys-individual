@echo off
setlocal
set "AWAKE_PACKAGE_DIRECTORY=%~dp0"
powershell.exe -NoProfile -Command "& ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $env:AWAKE_PACKAGE_DIRECTORY 'Set-Startup.ps1') -Raw))) -Action Disable -PackageDirectory $env:AWAKE_PACKAGE_DIRECTORY"
if errorlevel 1 exit /b 1
pause
