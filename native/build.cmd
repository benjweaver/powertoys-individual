@echo off
setlocal
if "%~1"=="" (echo Usage: build.cmd arm64^|x64 & exit /b 2)
if "%~2"=="" (set "PTI_VC=C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat") else (set "PTI_VC=%~2")
call "%PTI_VC%" %~1
if errorlevel 1 exit /b %errorlevel%
cd /d "%~dp0"
if not exist "bin\%~1" mkdir "bin\%~1"
cl /nologo /std:c++20 /EHsc /O2 /MT /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /DNOMINMAX Host.cpp /Fo"bin\%~1\Host.obj" /Fe"bin\%~1\PowerToysIndividual.exe" /link /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT
exit /b %errorlevel%
