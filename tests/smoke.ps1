param(
    [Parameter(Mandatory=$true)][string]$Package,
    [switch]$RequirePowerRequest,
    [string]$Report = '.\smoke-result.json'
)
$ErrorActionPreference = 'Stop'
$Package = (Resolve-Path $Package).Path
$exe = Join-Path $Package 'PowerToys.Awake.exe'
if (Get-Process -Name 'PowerToys','PowerToys.Awake' -ErrorAction SilentlyContinue) {
    throw 'Close existing PowerToys/Awake first; this test will not stop your applications.'
}
$manifest = Get-Content (Join-Path $Package 'package.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.files.PSObject.Properties) {
    $actual = (Get-FileHash (Join-Path $Package $entry.Name) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.Value) { throw "Hash mismatch: $($entry.Name)" }
}
$signature = Get-AuthenticodeSignature $exe
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    throw "Awake signature is not a valid Microsoft signature: $($signature.Status)"
}
$apps = @(Get-ChildItem $Package -Filter 'PowerToys*.exe' -Recurse)
if ($apps.Count -ne 1 -or $apps[0].Name -ne 'PowerToys.Awake.exe') { throw 'Other PowerToys apps found in package' }
$before = (& powercfg /getactivescheme | Out-String).Trim()
$parent = $null
$awake = $null
$result = [ordered]@{
    version = $manifest.version; architecture = $manifest.architecture
    hashes = 'passed'; microsoft_signature = 'passed'; only_awake = 'passed'
    started = $false; power_request = $false; pid_exit = $false; power_plan_unchanged = $false
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
}
try {
    $parent = Start-Process powershell.exe -ArgumentList '-NoProfile -Command Start-Sleep -Seconds 120' -PassThru -WindowStyle Hidden
    $awake = Start-Process $exe -ArgumentList "--pid=$($parent.Id)", '--display-on=true' -WorkingDirectory $Package -PassThru
    Start-Sleep -Seconds 5
    if ($awake.HasExited) { throw "Awake exited during launch: $($awake.ExitCode)" }
    $result.started = $true
    $requests = (& powercfg /requests | Out-String)
    $result.power_request = $requests -match 'PowerToys\.Awake\.exe'
    if ($RequirePowerRequest -and -not $result.power_request) { throw 'Windows did not report an Awake power request' }
    Stop-Process -Id $parent.Id
    if (-not $awake.WaitForExit(15000)) { throw 'Awake did not exit after its bound process ended' }
    if ($awake.ExitCode -ne 0) { throw "Awake exited with error: $($awake.ExitCode)" }
    $result.pid_exit = $true
    $after = (& powercfg /getactivescheme | Out-String).Trim()
    $result.power_plan_unchanged = $before -eq $after
    if (-not $result.power_plan_unchanged) { throw 'Active power plan changed' }
    $result.status = 'passed'
} catch {
    $result.status = 'failed'
    $result.error = $_.Exception.Message
    throw
} finally {
    if ($awake -and -not $awake.HasExited) { Stop-Process -Id $awake.Id -ErrorAction SilentlyContinue }
    if ($parent -and -not $parent.HasExited) { Stop-Process -Id $parent.Id -ErrorAction SilentlyContinue }
    $result | ConvertTo-Json | Set-Content -Encoding UTF8 $Report
}
$result | ConvertTo-Json
