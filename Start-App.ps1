param([Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference='Stop'
$PackageDirectory=(Resolve-Path $PackageDirectory).Path
$manifest=Get-Content (Join-Path $PackageDirectory 'package.json') -Raw | ConvertFrom-Json
if (Get-Process -Name PowerToys -ErrorAction SilentlyContinue) { throw 'Exit the full PowerToys suite before running an individual utility.' }
if ($manifest.utility -eq 'CommandNotFound') { Write-Output 'Command Not Found is enabled in your PowerShell 7 profile. Open a new PowerShell 7 session.'; return }
$exe=Join-Path $PackageDirectory 'PowerToysIndividual.exe'
if (-not (Test-Path $exe)) { throw 'Utility host is missing.' }
# The native host resides beside the vendor modules so their relative paths work.
Start-Process -FilePath $exe -WorkingDirectory $PackageDirectory
