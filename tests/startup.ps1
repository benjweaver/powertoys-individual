param([Parameter(Mandatory=$true)][string]$Package, [Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
$Package=(Resolve-Path $Package).Path
$exe=Join-Path $Package 'PowerToys.Awake.exe'
$process=@(Get-Process -Name PowerToys.Awake -ErrorAction SilentlyContinue | Where-Object Path -eq $exe)
if ($process.Count -ne 1) { throw 'Expected one package Awake instance in the desktop session.' }
if ($process[0].SessionId -ne (Get-Process -Id $PID).SessionId) { throw 'Run this test in the same desktop session as Awake.' }
$configPath=Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Awake\settings.json'
$config=Get-Content $configPath -Raw | ConvertFrom-Json
if ($config.properties.mode -ne 0) { throw 'Awake did not start Off.' }
if ((& powercfg /requests | Out-String) -match 'PowerToys\.Awake\.exe') { throw 'Off mode holds a power request.' }
$link=Join-Path ([Environment]::GetFolderPath('Startup')) 'PowerToys Individual Awake.lnk'
$shortcut=(New-Object -ComObject WScript.Shell).CreateShortcut($link)
if ($shortcut.Description -ne 'PowerToys Individual Awake startup shortcut' -or $shortcut.WorkingDirectory -ne $Package) { throw 'Startup shortcut is missing or targets another package.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ConsoleVisibilityTest {
 [DllImport("kernel32.dll")] public static extern bool FreeConsole();
 [DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
 [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
}
'@
[ConsoleVisibilityTest]::FreeConsole() | Out-Null
if (-not [ConsoleVisibilityTest]::AttachConsole([uint32]$process[0].Id)) { throw 'Could not inspect the Awake console.' }
try { $hidden=-not [ConsoleVisibilityTest]::IsWindowVisible([ConsoleVisibilityTest]::GetConsoleWindow()) }
finally { [ConsoleVisibilityTest]::FreeConsole() | Out-Null }
if (-not $hidden) { throw 'Debug console is visible.' }
$plan=(& powercfg /getactivescheme | Out-String).Trim()
try {
 $config.properties.mode=1
 $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
 Start-Sleep -Seconds 2
 if ((& powercfg /requests | Out-String) -notmatch 'PowerToys\.Awake\.exe') { throw 'Turning On did not create a request.' }
 $config.properties.mode=0
 $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
 Start-Sleep -Seconds 2
 if ((& powercfg /requests | Out-String) -match 'PowerToys\.Awake\.exe') { throw 'Turning Off did not release the request.' }
 if ((& powercfg /getactivescheme | Out-String).Trim() -ne $plan) { throw 'Power plan changed.' }
 [ordered]@{status='passed';startup_shortcut=$true;starts_off=$true;console_hidden=$hidden;on_creates_request=$true;off_releases_request=$true;power_plan_unchanged=$true;checked_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content $Report
} finally {
 $config.properties.mode=0
 $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}
