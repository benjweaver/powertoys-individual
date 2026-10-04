param(
    [string[]]$Apps = @('Awake'),
    [switch]$NoStartup,
    [switch]$NoLaunch,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'PowerToysIndividual'),
    [string]$PackageDirectory
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($env:OS -ne 'Windows_NT') { throw 'This installer runs on Windows only.' }
$repository = 'benjweaver/powertoys-individual'
$release = 'v0.1.1'
# Add utilities only after their standalone launch/dependency tests pass.
$catalog = @{
    Awake = @{
        arm64 = '9d55cb3fdadedce8ea6f6d40bd33c2c75469cc5abba65892e6cf51cbdaeb8a8a'
        x64 = '69dc87cd98c360d4290425a7bade8b794a0e84fb02c58ad1f36b4701bf053871'
    }
}
$selected = @($Apps | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique)
if ($selected.Count -eq 0) { throw 'Specify at least one app.' }
foreach ($app in $selected) {
    if (-not $catalog.ContainsKey($app)) { throw "Unsupported app '$app'. Currently available: Awake." }
}
$architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE', 'Machine').ToLowerInvariant()
if ($architecture -eq 'amd64') { $architecture = 'x64' }
if ($architecture -notin @('arm64','x64')) { throw "Unsupported Windows architecture: $architecture" }
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$existing = @(Get-Process -Name PowerToys.Awake -ErrorAction SilentlyContinue)
if (@($existing | Where-Object { $_.Path -notlike ($InstallRoot + '\*') }).Count) {
    throw 'Another Awake installation is running. Exit it before installing.'
}
function Quote-PS([string]$Text) { return "'" + $Text.Replace("'", "''") + "'" }
function Verify-Package([string]$Directory) {
    $manifest = Get-Content (Join-Path $Directory 'package.json') -Raw | ConvertFrom-Json
    if ($manifest.utility -ne 'Awake' -or $manifest.architecture -ne $architecture) { throw 'Package identity/architecture mismatch.' }
    foreach ($group in @('files','launcher_files')) {
        if (-not $manifest.$group) { throw "Missing package inventory: $group" }
        foreach ($entry in $manifest.$group.PSObject.Properties) {
            $path = [IO.Path]::GetFullPath((Join-Path $Directory $entry.Name))
            if (-not $path.StartsWith($Directory.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe package inventory path.' }
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value) { throw "Package file changed: $($entry.Name)" }
        }
    }
    $signature = Get-AuthenticodeSignature (Join-Path $Directory 'PowerToys.Awake.exe')
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { throw 'Awake does not have a valid Microsoft signature.' }
}
$temp = Join-Path $env:TEMP ('PowerToysIndividual-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    foreach ($app in $selected) {
        $name = 'Awake-' + $architecture + '.zip'
        $archive = Join-Path $temp $name
        if ($PackageDirectory) {
            Copy-Item -LiteralPath (Join-Path $PackageDirectory $name) -Destination $archive
        } else {
            $url = 'https://github.com/' + $repository + '/releases/download/' + $release + '/' + $name
            Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        }
        if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $catalog.Awake[$architecture]) { throw 'Release archive SHA-256 mismatch.' }
        $expanded = Join-Path $temp 'expanded'
        Expand-Archive -LiteralPath $archive -DestinationPath $expanded
        $payload = Join-Path $expanded ('Awake-' + $architecture)
        Verify-Package $payload
        $destination = Join-Path $InstallRoot ('Awake\' + $release + '-' + $architecture)
        if (Test-Path $destination) {
            Verify-Package $destination
        } else {
            New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
            Move-Item -LiteralPath $payload -Destination $destination
        }
        $startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'PowerToys Individual'
        $link = Join-Path $startMenu 'Awake.lnk'
        $shell = New-Object -ComObject WScript.Shell
        $marker = 'PowerToys Individual Awake app shortcut'
        if (Test-Path $link) {
            if ($shell.CreateShortcut($link).Description -ne $marker) { throw 'An unrelated Start Menu shortcut already uses this name.' }
        }
        New-Item -ItemType Directory -Path $startMenu -Force | Out-Null
        $launcher = Join-Path $destination 'Start-Awake.ps1'
        $command = '& ([scriptblock]::Create((Get-Content -LiteralPath ' + (Quote-PS $launcher) + ' -Raw))) -PackageDirectory ' + (Quote-PS $destination)
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments = '-NoProfile -WindowStyle Hidden -EncodedCommand ' + $encoded
        $shortcut = $shell.CreateShortcut($link)
        $shortcut.TargetPath = $powershell
        $shortcut.Arguments = $arguments
        $shortcut.WorkingDirectory = $destination
        $shortcut.IconLocation = (Join-Path $destination 'PowerToys.Awake.exe') + ',0'
        $shortcut.Description = $marker
        $shortcut.Save()
        $startupAction = if ($NoStartup) { 'Disable' } else { 'Enable' }
        & ([scriptblock]::Create((Get-Content (Join-Path $destination 'Set-Startup.ps1') -Raw))) -Action $startupAction -PackageDirectory $destination
        if (-not $NoLaunch) { Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden }
        [ordered]@{app='Awake';release=$release;architecture=$architecture;path=$destination;startup=(-not $NoStartup);starts_off=$true;installed_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $InstallRoot 'Awake-install.json') -Encoding UTF8
        Write-Output "Awake installed: $destination"
        Write-Output 'Find Awake in the Start Menu. It starts Off; use its tray menu to turn it On.'
    }
} finally {
    # This directory was created solely for this install attempt.
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
