param(
    [Parameter(Mandatory=$true)][string]$Package,
    [Parameter(Mandatory=$true)][string]$Report,
    [switch]$StartupTest,
    [string]$SmokeScript = (Join-Path $PSScriptRoot 'smoke.ps1')
)
$ErrorActionPreference = 'Stop'
$Package = (Resolve-Path $Package).Path
$SmokeScript = (Resolve-Path $SmokeScript).Path
$Report = [IO.Path]::GetFullPath($Report)
if (Test-Path $Report) { throw 'Choose a new report path; existing reports are not overwritten.' }
$taskName = 'PowerToysIndividual-Smoke-' + [Guid]::NewGuid().ToString('N')
function Quote-PS([string]$Text) { return "'" + $Text.Replace("'", "''") + "'" }
$command = '& ([scriptblock]::Create((Get-Content ' + (Quote-PS $SmokeScript) + ' -Raw))) -Package ' + (Quote-PS $Package) + ' -Report ' + (Quote-PS $Report)
if (-not $StartupTest) { $command += ' -RequirePowerRequest' }
$command += ' *> ' + (Quote-PS ($Report + '.log'))
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -EncodedCommand ' + $encoded)
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
$registered = $false
try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal | Out-Null
    $registered = $true
    Start-ScheduledTask -TaskName $taskName
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        Start-Sleep -Seconds 1
        $state = (Get-ScheduledTask -TaskName $taskName).State
    } while ((-not (Test-Path $Report) -or $state -eq 'Running') -and [DateTime]::UtcNow -lt $deadline)
    if ($state -eq 'Running') { throw 'Desktop smoke test exceeded 45 seconds' }
    if (-not (Test-Path $Report)) { Get-Content ($Report + '.log') -ErrorAction SilentlyContinue | Write-Output; throw 'No report created. Check the test log and desktop login.' }
    $result = Get-Content $Report -Raw | ConvertFrom-Json
    $result | ConvertTo-Json
    if ($result.status -ne 'passed') { throw 'Desktop smoke test failed; see report.' }
} finally {
    if ($registered) {
        if ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running') { Stop-ScheduledTask -TaskName $taskName }
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}
