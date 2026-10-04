param([string]$PackageDirectory = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$PackageDirectory = (Resolve-Path $PackageDirectory).Path
$exe = Join-Path $PackageDirectory 'PowerToys.Awake.exe'
if (-not (Test-Path $exe -PathType Leaf)) { throw 'Awake executable is missing.' }
$existing = @(Get-Process -Name 'PowerToys.Awake' -ErrorAction SilentlyContinue)
if (@($existing | Where-Object { $_.Path -ne $exe }).Count -gt 0) {
    throw 'Another Awake installation is running. Exit it before launching this package.'
}
$configDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Awake'
$configPath = Join-Path $configDirectory 'settings.json'
New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
if (Test-Path $configPath) {
    $settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if (-not $settings.properties) { throw 'Existing Awake settings are invalid.' }
    $settings.properties.mode = 0
} else {
    $settings = [ordered]@{
        name = 'Awake'; version = '1.0'
        properties = [ordered]@{
            keepDisplayOn = $true; mode = 0; intervalHours = 0; intervalMinutes = 30
            expirationDateTime = [DateTimeOffset]::Now.ToString('o')
            customTrayTimes = [ordered]@{'30 minutes' = 1800; '1 hour' = 3600; '2 hours' = 7200}
        }
    }
}
# Always reset to Off when this launcher is used, including at sign-in.
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
if ($existing.Count -gt 0) {
    # The package's config-aware instance receives the Off update automatically.
    $awakeProcess = $existing[0]
} else {
    $awakeProcess = Start-Process -FilePath $exe -ArgumentList '--use-pt-config' -WorkingDirectory $PackageDirectory -WindowStyle Hidden -PassThru
}
# Upstream allocates a debug console even though Awake is a tray app. Attach
# only to this Awake process's console and hide it, preserving the native Exit
# menu (using --pid would suppress Exit). No helper process stays resident.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AwakeConsole {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
}
'@
[AwakeConsole]::FreeConsole() | Out-Null
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $awakeProcess.Refresh()
    if ($awakeProcess.HasExited) { throw 'Awake exited during startup.' }
    if ([AwakeConsole]::AttachConsole([uint32]$awakeProcess.Id)) {
        try {
            $window = [AwakeConsole]::GetConsoleWindow()
            if ($window -ne [IntPtr]::Zero) { [AwakeConsole]::ShowWindow($window, 0) | Out-Null }
        } finally { [AwakeConsole]::FreeConsole() | Out-Null }
        break
    }
    Start-Sleep -Milliseconds 100
}
