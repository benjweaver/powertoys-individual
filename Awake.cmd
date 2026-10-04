@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  start "" "%~dp0PowerToys.Awake.exe"
) else (
  start "" "%~dp0PowerToys.Awake.exe" %*
)
