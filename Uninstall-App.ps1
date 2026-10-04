param(
 [Parameter(Mandatory=$true)][string]$PackageDirectory,
 [string]$ExpectedApp,
 [switch]$ShowMessage
)
$ErrorActionPreference='Stop'
$PackageDirectory=(Resolve-Path -LiteralPath $PackageDirectory).Path.TrimEnd('\')
$manifest=Get-Content -LiteralPath (Join-Path $PackageDirectory 'package.json') -Raw | ConvertFrom-Json
$app=$manifest.utility
if(-not $app -or $app -notmatch '^[A-Za-z]+$' -or ($ExpectedApp -and $app -ne $ExpectedApp)){throw 'Package identity does not match the uninstall request.'}
$parent=Split-Path $PackageDirectory
if((Split-Path $parent -Leaf) -ne $app){throw 'Use the installer to manage this package; its directory must match its app name.'}
$root=Split-Path $parent
$receiptPath=Join-Path $root ($app+'-install.json')
if(-not(Test-Path $receiptPath)){throw 'The installation receipt is missing. No files were removed.'}
$receipt=Get-Content $receiptPath -Raw | ConvertFrom-Json
if($receipt.app -ne $app -or [IO.Path]::GetFullPath($receipt.path).TrimEnd('\') -ne $PackageDirectory){throw 'Installation receipt does not match this package.'}
if(Get-Process -Name PowerToys -ErrorAction SilentlyContinue){throw 'Exit the full PowerToys suite before uninstalling individual utilities.'}
# Never traverse a junction or symlink, including an ancestor of the install root.
function Assert-PlainPath([string]$Path){
 while($Path){
  if(Test-Path -LiteralPath $Path){if((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Refusing a linked path: $Path"}}
  $next=Split-Path $Path;if($next -eq $Path){break};$Path=$next
 }
}
Assert-PlainPath $PackageDirectory
# Check every inventory path before stopping the app or changing registrations.
$files=@()
$directories=@($PackageDirectory)
foreach($candidate in Get-ChildItem -LiteralPath $parent -Directory){
 if($candidate.FullName -eq $PackageDirectory){continue}
 Assert-PlainPath $candidate.FullName
 $identity=Join-Path $candidate.FullName 'package.json'
 if(Test-Path $identity){
  $old=Get-Content $identity -Raw | ConvertFrom-Json
  if($old.utility -eq $app -and $candidate.Name -match '^v[0-9]+\.[0-9]+\.[0-9]+-(arm64|x64)$'){
   foreach($name in @($old.files.PSObject.Properties.Name)+@($old.launcher_files.PSObject.Properties.Name)){
    $path=[IO.Path]::GetFullPath((Join-Path $candidate.FullName $name))
    if(-not $path.StartsWith($candidate.FullName+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe old package inventory.'}
    Assert-PlainPath $path;$files+=$path
   }
   $directories+=$candidate.FullName
   $files+=$identity
  }
 }
}
foreach($name in $manifest.files.PSObject.Properties.Name){
 $path=[IO.Path]::GetFullPath((Join-Path $PackageDirectory $name))
 if(-not $path.StartsWith($PackageDirectory+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe package inventory.'}
 Assert-PlainPath $path;$files+=$path
}
$retryFiles=@('Uninstall-App.ps1','package.json','install-state.json')
$files=@($files | Where-Object {$_ -notin @($retryFiles | ForEach-Object {Join-Path $PackageDirectory $_})})
$files+=Join-Path $PackageDirectory 'host.log'
$ownedProcesses=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$processPath=$_.Path;$processPath -and @($directories | Where-Object {$processPath.StartsWith($_+'\',[StringComparison]::OrdinalIgnoreCase)}).Count})
if($app -eq 'Awake'){$ownedProcesses | Stop-Process}
elseif(@($ownedProcesses | Where-Object Path -eq (Join-Path $PackageDirectory 'PowerToysIndividual.exe')).Count){& (Join-Path $PackageDirectory 'PowerToysIndividual.exe') --quit}
foreach($process in $ownedProcesses){if(-not $process.HasExited -and -not $process.WaitForExit(10000)){throw 'The utility did not exit. Close it from its tray menu, then retry uninstall.'}}
if($app -eq 'CommandNotFound'){
 $pwsh=Get-Command pwsh.exe -ErrorAction Stop
 $code=@'
$ErrorActionPreference='Stop'
if(Test-Path $PROFILE){
 $content=[IO.File]::ReadAllText($PROFILE)
 $pattern='(?ms)^# BEGIN PowerToysIndividual CommandNotFound\r?\n.*?^# END PowerToysIndividual CommandNotFound\r?\n?'
 $updated=[regex]::Replace($content,$pattern,'')
 if($updated -ne $content){[IO.File]::WriteAllText($PROFILE,$updated,(New-Object Text.UTF8Encoding($false)))}
}
'@
 & $pwsh.Source -NoProfile -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code)))
 if($LASTEXITCODE -ne 0){throw 'Could not remove the owned PowerShell profile block.'}
}
# Command Palette is removed only when this installer originally registered it.
$statePath=Join-Path $PackageDirectory 'install-state.json'
if(Test-Path $statePath){
 $state=Get-Content $statePath -Raw | ConvertFrom-Json
 foreach($fullName in $state.owned_appx){
  if($fullName -notlike 'Microsoft.CommandPalette_*'){throw 'Unexpected AppX ownership entry.'}
  $package=Get-AppxPackage -Name Microsoft.CommandPalette | Where-Object PackageFullName -eq $fullName
  if($package){Remove-AppxPackage -Package $package.PackageFullName}
 }
}
# Sparse shell packages belong to this installation only if their external path matches.
$null=[Windows.Management.Deployment.PackageManager,Windows.Management.Deployment,ContentType=WindowsRuntime]
$manager=New-Object Windows.Management.Deployment.PackageManager
foreach($package in @(Get-AppxPackage -Name Microsoft.PowerToys.*)){
 $external=$manager.FindPackageForUser('', $package.PackageFullName).EffectiveExternalLocation
 if($external -and $external.Path -and ($external.Path.TrimEnd('\') -eq $PackageDirectory -or $external.Path.StartsWith($PackageDirectory+'\',[StringComparison]::OrdinalIgnoreCase))){Remove-AppxPackage $package.PackageFullName}
}
$shell=New-Object -ComObject WScript.Shell
foreach($folder in @([Environment]::GetFolderPath('Startup'),(Join-Path ([Environment]::GetFolderPath('Programs')) 'PowerToys Individual'))){
 foreach($name in @(('PowerToys Individual '+$app+'.lnk'), ($app+'.lnk'))){
  $link=Join-Path $folder $name
  if(Test-Path $link){
   $shortcut=$shell.CreateShortcut($link)
   if($shortcut.Description -in @(('PowerToys Individual '+$app),('PowerToys Individual '+$app+' startup shortcut'),('PowerToys Individual '+$app+' app shortcut')) -and $shortcut.WorkingDirectory.TrimEnd('\') -in $directories){Remove-Item -LiteralPath $link}
  }
 }
}
$remaining=@()
foreach($file in $files | Select-Object -Unique){
 if(Test-Path -LiteralPath $file){try{Remove-Item -LiteralPath $file -Force}catch{$remaining+=$file}}
}
# Do not recursively delete unknown files added by the user.
$emptyCandidates=@($files | ForEach-Object {
 $directory=Split-Path $_
 while($directory -and $directory -ne $parent){$directory;$directory=Split-Path $directory}
} | Select-Object -Unique | Sort-Object Length -Descending)
foreach($directory in $emptyCandidates){
 if(Test-Path -LiteralPath $directory){if(-not @(Get-ChildItem -LiteralPath $directory -Force).Count){Remove-Item -LiteralPath $directory}}
}
if($remaining.Count){throw 'Some package files are still in use. Sign out and back in, then retry uninstall from Installed apps. Startup has been disabled; settings are preserved.'}
foreach($name in $retryFiles){$file=Join-Path $PackageDirectory $name;if(Test-Path $file){Remove-Item -LiteralPath $file -Force}}
foreach($directory in $directories){
 if(Test-Path -LiteralPath $directory){
  if(-not @(Get-ChildItem -LiteralPath $directory -Force).Count){Remove-Item -LiteralPath $directory}
  else{
   $name='Preserved-'+(Split-Path $directory -Leaf)+'-'+[Guid]::NewGuid().ToString('N')
   Rename-Item -LiteralPath $directory -NewName $name
   Write-Output ('User-added files preserved at: '+(Join-Path $parent $name))
  }
 }
}
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PowerToysIndividual-'+$app
if(Test-Path $key){$registration=Get-ItemProperty $key;if($registration.PowerToysIndividualOwner -eq $receipt.path){Remove-Item $key}}
Remove-Item -LiteralPath $receiptPath
foreach($directory in @($directories)+@($parent,$root)){if(Test-Path $directory){if(-not @(Get-ChildItem -LiteralPath $directory -Force).Count){Remove-Item -LiteralPath $directory}}}
$message="$app uninstalled. User settings and shared dependencies are preserved."
Write-Output $message
if($ShowMessage){Add-Type -AssemblyName System.Windows.Forms;[Windows.Forms.MessageBox]::Show($message,'PowerToys Individual') | Out-Null}
