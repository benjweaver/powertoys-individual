param([Parameter(Mandatory=$true)][string]$Package,[Parameter(Mandatory=$true)][string]$Report,[ValidateSet('arm64','x64')][string]$Architecture='arm64')
$ErrorActionPreference='Stop'
$results=@();$signatures=@{}
$theme='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$originalTheme=Get-ItemProperty $theme
function Save-Progress([string]$Status,[string]$Current){
 @{status=$Status;current=$Current;architecture=$Architecture;validation='module lifecycle and activation smoke; physical hardware features not covered';results=$results;checked_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Depth 7 | Set-Content $Report -Encoding UTF8
}
try{
 foreach($directory in Get-ChildItem $Package -Directory -Filter ('*-'+$Architecture) | Sort-Object Name){
  $app=$directory.Name.Substring(0,$directory.Name.Length-$Architecture.Length-1)
  if($app -in @('Awake','CommandNotFound')){continue}
  Save-Progress 'running' $app
  $process=$null;$passed=$false;$errorText='';$children=@();$started=Get-Date
  try{
   $manifest=Get-Content (Join-Path $directory.FullName 'package.json') -Raw | ConvertFrom-Json
   foreach($target in $manifest.signature_targets){
    $file=Join-Path $directory.FullName $target;$hash=(Get-FileHash $file -Algorithm SHA256).Hash
    if(-not $signatures.ContainsKey($hash)){
     $sig=Get-AuthenticodeSignature $file
     if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw "Invalid Microsoft signature: $target"}
     $signatures[$hash]=$true
    }
   }
   & ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $directory.FullName 'Setup-App.ps1')))) -PackageDirectory $directory.FullName
   $log=Join-Path $directory.FullName 'host.log';Remove-Item $log -ErrorAction SilentlyContinue
   $process=Start-Process (Join-Path $directory.FullName 'PowerToysIndividual.exe') -ArgumentList '--smoke' -WorkingDirectory $directory.FullName -PassThru
   Start-Sleep -Seconds 3
   $children=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.Path -and $_.Path.StartsWith($directory.FullName+'\') -and $_.Id -ne $process.Id} | ForEach-Object {$_.ProcessName})
   $finished=$process.WaitForExit(20000)
   $text=if(Test-Path $log){[IO.File]::ReadAllText($log)}else{''}
   if(-not $finished){throw 'Host did not shut down within 23 seconds.'}
   if($process.ExitCode -ne 0){throw "Host exited with code $($process.ExitCode): $text"}
   if(-not $text.Contains('Ready;') -or -not $text.Contains('Stopped')){throw "Incomplete lifecycle: $text"}
   $passed=$true
  }catch{$errorText=$_.Exception.Message}
  finally{
   if($process -and -not $process.HasExited){$process.Kill()}
   Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.Path -and $_.Path.StartsWith($directory.FullName+'\')} | Stop-Process -ErrorAction SilentlyContinue
  }
  $results+=@{app=$app;passed=$passed;error=$errorText;child_processes=$children;elapsed_seconds=[Math]::Round(((Get-Date)-$started).TotalSeconds,2)}
  Save-Progress 'running' $app
 }
 Save-Progress $(if(@($results | Where-Object {-not $_.passed}).Count){'failed'}else{'passed'}) ''
}finally{
 foreach($name in @('AppsUseLightTheme','SystemUsesLightTheme')){if($null -ne $originalTheme.$name){Set-ItemProperty $theme $name $originalTheme.$name}}
}
