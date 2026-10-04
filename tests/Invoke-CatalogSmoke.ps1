param([Parameter(Mandatory=$true)][string]$Package,[Parameter(Mandatory=$true)][string]$Report,[Parameter(Mandatory=$true)][string]$SmokeScript,[ValidateSet('arm64','x64')][string]$Architecture='arm64')
$ErrorActionPreference='Stop'
if(Test-Path $Report){throw 'Choose a fresh report path.'}
$name='PowerToysIndividual-Catalog-'+[Guid]::NewGuid().ToString('N')
function Quote([string]$Text){return "'"+$Text.Replace("'","''")+"'"}
$command='& ([scriptblock]::Create([IO.File]::ReadAllText('+(Quote $SmokeScript)+'))) -Package '+(Quote $Package)+' -Report '+(Quote $Report)+' -Architecture '+(Quote $Architecture)+' *> '+(Quote ($Report+'.log'))
$action=New-ScheduledTaskAction -Execute powershell.exe -Argument ('-NoProfile -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command)))
$principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
Start-ScheduledTask $name
[pscustomobject]@{task=$name;report=$Report;note='Poll the report for progress; unregister this temporary task after completion.'} | ConvertTo-Json
