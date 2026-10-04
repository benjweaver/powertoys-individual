param(
    [ValidateSet('Enable','Disable','Status')][string]$Action = 'Enable',
    [string]$PackageDirectory = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$PackageDirectory = (Resolve-Path $PackageDirectory).Path
$exe = Join-Path $PackageDirectory 'PowerToys.Awake.exe'
$startup = [Environment]::GetFolderPath('Startup')
$link = Join-Path $startup 'PowerToys Individual Awake.lnk'
$marker = 'PowerToys Individual Awake startup shortcut'
$shell = New-Object -ComObject WScript.Shell
if (Test-Path $link) {
    $existing = $shell.CreateShortcut($link)
    if ($existing.Description -ne $marker) { throw 'A startup shortcut with this name already exists and is not owned by this package.' }
}
switch ($Action) {
    'Enable' {
        if (-not (Test-Path $exe -PathType Leaf)) { throw 'Keep this script in the Awake package folder.' }
        $shortcut = $shell.CreateShortcut($link)
        $launcher = Join-Path $PackageDirectory 'Start-Awake.ps1'
        if (-not (Test-Path $launcher -PathType Leaf)) { throw 'Startup launcher is missing.' }
        function Quote-PS([string]$text) { return "'" + $text.Replace("'", "''") + "'" }
        $command = '& ([scriptblock]::Create((Get-Content -LiteralPath ' + (Quote-PS $launcher) + ' -Raw))) -PackageDirectory ' + (Quote-PS $PackageDirectory)
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $shortcut.WorkingDirectory = $PackageDirectory
        $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -EncodedCommand ' + $encoded
        $shortcut.Description = $marker
        $shortcut.IconLocation = $exe + ',0'
        $shortcut.Save()
        Write-Output "Startup enabled for this Windows user: $link"
    }
    'Disable' {
        if (Test-Path $link) { Remove-Item -LiteralPath $link }
        Write-Output 'Awake startup disabled for this Windows user.'
    }
    'Status' {
        if (Test-Path $link) { Write-Output ('Enabled: ' + $existing.WorkingDirectory + ' (starts Off)') }
        else { Write-Output 'Disabled' }
    }
}
