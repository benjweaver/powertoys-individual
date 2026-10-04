param([Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference='Stop'
$manifest=Get-Content (Join-Path $PackageDirectory 'package.json') -Raw | ConvertFrom-Json
switch ($manifest.utility) {
 'FileExplorerAddons' {
  $folder=Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\File Explorer'
  $file=Join-Path $folder 'settings.json'
  if (-not (Test-Path $file)) {
   New-Item -ItemType Directory $folder -Force | Out-Null
   $properties=[ordered]@{}
   foreach ($name in @('svg-previewer','md-previewer','monaco-previewer','pdf-previewer','gcode-previewer','bgcode-previewer','qoi-previewer','svg-thumbnail','pdf-thumbnail','gcode-thumbnail','bgcode-thumbnail','stl-thumbnail','qoi-thumbnail')) { $properties[$name+'-toggle-setting']=@{value=$true} }
   @{name='File Explorer';version='1.0';properties=$properties} | ConvertTo-Json -Depth 8 | Set-Content $file -Encoding UTF8
  }
 }
 'CommandPalette' {
  if (-not (Get-AppxPackage -Name Microsoft.CommandPalette)) {
   $msix=Get-ChildItem (Join-Path $PackageDirectory 'WinUI3Apps\CmdPal') -Filter *.msix | Select-Object -First 1
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $dependencies=@()
   foreach($file in Get-ChildItem (Join-Path $PackageDirectory 'WinUI3Apps\CmdPal\Dependencies') -Recurse -Filter *.appx){
    $zip=[IO.Compression.ZipFile]::OpenRead($file.FullName)
    try{
     $reader=New-Object IO.StreamReader($zip.GetEntry('AppxManifest.xml').Open())
     try{$xml=[xml]$reader.ReadToEnd()}finally{$reader.Dispose()}
    }finally{$zip.Dispose()}
    $identity=$xml.Package.Identity
    $compatible=@(Get-AppxPackage -Name $identity.Name | Where-Object { [Version]$_.Version -ge [Version]$identity.Version -and $_.Architecture.ToString().ToLowerInvariant() -eq $identity.ProcessorArchitecture -and $_.Publisher -eq $identity.Publisher })
    if(-not $compatible.Count){$dependencies+=$file.FullName}
   }
   $parameters=@{Path=$msix.FullName}
   if($dependencies.Count){$parameters.DependencyPath=$dependencies}
   Add-AppxPackage @parameters
   $owned=@(Get-AppxPackage -Name Microsoft.CommandPalette | ForEach-Object PackageFullName)
   @{owned_appx=$owned} | ConvertTo-Json | Set-Content (Join-Path $PackageDirectory 'install-state.json') -Encoding UTF8
  }
 }
 'CommandNotFound' {
  $pwsh=Get-Command pwsh.exe -ErrorAction SilentlyContinue
  if (-not $pwsh) {
   if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'Command Not Found requires PowerShell 7.4 or newer. Install Microsoft.PowerShell, then rerun.' }
   & winget install --id Microsoft.PowerShell --exact --source winget --silent --accept-package-agreements --accept-source-agreements
   if ($LASTEXITCODE -ne 0) { throw 'Could not install PowerShell 7.' }
   $pwsh=Get-Command pwsh.exe -ErrorAction SilentlyContinue
   $pwshPath=if($pwsh){$pwsh.Source}else{Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe'}
   if(-not (Test-Path $pwshPath)){throw 'PowerShell was installed but its launcher is unavailable. Reopen PowerShell and rerun.'}
  } else { $pwshPath=$pwsh.Source }
  $script=@'
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSVersion -lt [Version]'7.4') { throw 'PowerShell 7.4 or newer is required.' }
foreach($module in @(@{Name='Microsoft.WinGet.Client';Version='1.12.440'},@{Name='Microsoft.WinGet.CommandNotFound';Version='1.0.4.0'})){
 if(-not (Get-Module -ListAvailable $module.Name | Where-Object Version -eq ([Version]$module.Version))){Install-Module $module.Name -RequiredVersion $module.Version -Repository PSGallery -Scope CurrentUser -Force}
}
foreach ($feature in @('PSFeedbackProvider','PSCommandNotFoundSuggestion')) {
 if (Get-ExperimentalFeature -Name $feature -ErrorAction SilentlyContinue) { Enable-ExperimentalFeature $feature -Scope CurrentUser | Out-Null }
}
$begin='# BEGIN PowerToysIndividual CommandNotFound'
$end='# END PowerToysIndividual CommandNotFound'
$content=if(Test-Path $PROFILE){[IO.File]::ReadAllText($PROFILE)}else{''}
if($null -eq $content){$content=''}
if (-not $content.Contains($begin)) {
 New-Item -ItemType Directory (Split-Path $PROFILE) -Force | Out-Null
 if (Test-Path $PROFILE) { Copy-Item $PROFILE ($PROFILE+'.powertoys-individual.bak') -Force }
 Add-Content $PROFILE ("`n"+$begin+"`nImport-Module Microsoft.WinGet.CommandNotFound -RequiredVersion 1.0.4.0`n"+$end) -Encoding UTF8
}
Import-Module Microsoft.WinGet.CommandNotFound -RequiredVersion 1.0.4.0
'@
  $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
  & $pwshPath -NoProfile -EncodedCommand $encoded
  if ($LASTEXITCODE -ne 0) { throw 'Command Not Found setup failed.' }
 }
}
