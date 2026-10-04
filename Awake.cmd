@echo off
setlocal
set "AWAKE_PACKAGE_DIRECTORY=%~dp0"
if "%~1"=="" (
  powershell.exe -NoProfile -WindowStyle Hidden -Command "& ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $env:AWAKE_PACKAGE_DIRECTORY 'Start-Awake.ps1') -Raw))) -PackageDirectory $env:AWAKE_PACKAGE_DIRECTORY"
) else (
  start "" "%~dp0PowerToys.Awake.exe" %*
)
