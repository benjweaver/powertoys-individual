param([Parameter(Mandatory=$true)][string]$Fixture,[Parameter(Mandatory=$true)][string]$Output,[Parameter(Mandatory=$true)][ValidateSet('arm64','x64')][string]$Architecture)
$ErrorActionPreference='Stop'
$inventory=Get-Content (Join-Path $Fixture 'inventories.json') -Raw | ConvertFrom-Json
$recipes=Get-Content (Join-Path $Fixture 'recipes.json') -Raw | ConvertFrom-Json
foreach($entry in $inventory.PSObject.Properties){
 $app=$entry.Name;$folder=Join-Path $Output ($app+'-'+$Architecture)
 New-Item -ItemType Directory $folder -Force | Out-Null
 foreach($relative in $entry.Value){
  $source=Join-Path (Join-Path $Fixture 'cache') $relative
  $target=Join-Path $folder $relative
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
  [IO.File]::Copy($source,$target,$true)
 }
 $recipe=$recipes.$app
 $ini="[App]`nName=$app`n"
 for($i=0;$i -lt $recipe.modules.Count;$i++){$ini+='Module'+$i+'='+$recipe.modules[$i]+"`n"}
 if($recipe.editor){$ini+='Editor='+$recipe.editor+"`n"}
 if($recipe.editor_event){$ini+='EditorEvent='+$recipe.editor_event+"`n"}
 $ini | Set-Content (Join-Path $folder 'app.ini') -Encoding Unicode
 if($recipe.modules.Count){[IO.File]::Copy((Join-Path $Fixture 'host\PowerToysIndividual.exe'),(Join-Path $folder 'PowerToysIndividual.exe'),$true)}
 foreach($file in @('Start-App.ps1','Setup-App.ps1','Start-Awake.ps1','Set-Startup.ps1','Uninstall-App.ps1')){[IO.File]::Copy((Join-Path $Fixture $file),(Join-Path $folder $file),$true)}
 @{utility=$app;architecture=$Architecture;signature_targets=@($recipe.modules)+@($recipe.executables);notes=$recipe.notes} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $folder 'package.json') -Encoding UTF8
}
Write-Output "Prepared $(@($inventory.PSObject.Properties).Count) $Architecture test packages."
