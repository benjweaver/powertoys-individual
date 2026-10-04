# Run in Windows PowerShell; exercises ownership, traversal rejection, and preservation.
param([string]$Uninstaller=(Join-Path (Split-Path $PSScriptRoot) 'Uninstall-App.ps1'))
$ErrorActionPreference='Stop'
$code=[scriptblock]::Create([IO.File]::ReadAllText((Resolve-Path $Uninstaller).Path))
$root=Join-Path $env:TEMP ('PowerToysIndividual-UninstallTest-'+[Guid]::NewGuid().ToString('N'))
$directory=Join-Path $root 'Awake\vtest-arm64'
New-Item -ItemType Directory $directory -Force | Out-Null
try{
 Copy-Item $Uninstaller $directory
 Set-Content (Join-Path $directory 'owned.txt') 'owned'
 Set-Content (Join-Path $directory 'user-added.txt') 'preserve'
 $receipt=Join-Path $root 'Awake-install.json'
 @{app='Other';path=$directory} | ConvertTo-Json | Set-Content $receipt
 $manifest=@{utility='Awake';files=@{'owned.txt'='test';'Uninstall-App.ps1'='test'}}
 $manifest | ConvertTo-Json | Set-Content (Join-Path $directory 'package.json')
 $rejected=$false
 try{& $code -PackageDirectory $directory -ExpectedApp Awake}catch{$rejected=$true}
 if(-not $rejected -or -not(Test-Path (Join-Path $directory 'owned.txt'))){throw 'Mismatched receipt was not rejected safely.'}
 @{app='Awake';path=$directory} | ConvertTo-Json | Set-Content $receipt
 $manifest.files['..\escape.txt']='test'
 $manifest | ConvertTo-Json | Set-Content (Join-Path $directory 'package.json')
 $rejected=$false
 try{& $code -PackageDirectory $directory -ExpectedApp Awake}catch{$rejected=$true}
 if(-not $rejected -or -not(Test-Path (Join-Path $directory 'owned.txt'))){throw 'Escaping inventory was not rejected safely.'}
 $manifest.files.Remove('..\escape.txt')
 $manifest | ConvertTo-Json | Set-Content (Join-Path $directory 'package.json')
 & $code -PackageDirectory $directory -ExpectedApp Awake
 if(Test-Path (Join-Path $directory 'owned.txt')){throw 'Owned file retained.'}
 if(-not @(Get-ChildItem $root -Recurse -File -Filter 'user-added.txt').Count){throw 'User-added file removed.'}
 if(Test-Path $receipt){throw 'Receipt retained.'}
 'Uninstall checks passed: receipt ownership, path traversal rejection, owned-file removal, user-file preservation.'
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
