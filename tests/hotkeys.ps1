param([Parameter(Mandatory=$true)][string]$Package,[Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class InputTest {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
 [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtr(IntPtr window,int index);
 [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
}
'@
$form=New-Object Windows.Forms.Form
$form.Text='PowerToys Individual disposable hotkey test';$form.Width=480;$form.Height=160
$form.KeyPreview=$true;$form.Show()
$ctrlSpace=@{received=$false}
$form.Add_KeyDown({param($sender,$event) if($event.Control -and $event.KeyCode -eq [Windows.Forms.Keys]::Space){$ctrlSpace.received=$true}})
function Pump([int]$Milliseconds){$end=[DateTime]::UtcNow.AddMilliseconds($Milliseconds);do{[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 10}while([DateTime]::UtcNow -lt $end)}
function Chord([byte[]]$Keys){foreach($key in $Keys){[InputTest]::keybd_event($key,0,0,[UIntPtr]::Zero);Pump 50};for($i=$Keys.Count-1;$i -ge 0;$i--){[InputTest]::keybd_event($Keys[$i],0,2,[UIntPtr]::Zero);Pump 50};Pump 1000}
$hostProcess=$null
try{
 $folder=Join-Path $Package 'AlwaysOnTop-arm64'
 [IO.File]::Copy('C:\Users\dev\powertoys-individual\native\bin\arm64\PowerToysIndividual.exe',(Join-Path $folder 'PowerToysIndividual.exe'),$true)
 $hostProcess=Start-Process (Join-Path $folder 'PowerToysIndividual.exe') -WorkingDirectory $folder -PassThru
 Pump 2000;[InputTest]::SetForegroundWindow($form.Handle)|Out-Null;Pump 200
 Chord @(0x5B,0x11,0x54)
 $pinned=([InputTest]::GetWindowLongPtr($form.Handle,-20).ToInt64() -band 8) -ne 0
 if(-not $pinned){throw 'Win+Ctrl+T did not pin the disposable window.'}
 Chord @(0x5B,0x11,0x54)
 $unpinned=([InputTest]::GetWindowLongPtr($form.Handle,-20).ToInt64() -band 8) -eq 0
 if(-not $unpinned){throw 'Win+Ctrl+T did not unpin the window.'}
 & (Join-Path $folder 'PowerToysIndividual.exe') --quit
 if(-not $hostProcess.WaitForExit(10000)){throw 'Quit command did not stop the host.'}
 $folder=Join-Path $Package 'Peek-arm64'
 [IO.File]::Copy('C:\Users\dev\powertoys-individual\native\bin\arm64\PowerToysIndividual.exe',(Join-Path $folder 'PowerToysIndividual.exe'),$true)
 $hostProcess=Start-Process (Join-Path $folder 'PowerToysIndividual.exe') -WorkingDirectory $folder -PassThru
 Pump 2000;[InputTest]::SetForegroundWindow($form.Handle)|Out-Null;Pump 200
 Chord @(0x11,0x20)
 if(-not $ctrlSpace.received){throw 'Peek swallowed Ctrl+Space outside Explorer.'}
 & (Join-Path $folder 'PowerToysIndividual.exe') --quit
 if(-not $hostProcess.WaitForExit(10000)){throw 'Peek host did not stop.'}
 @{status='passed';always_on_top_pin=$pinned;always_on_top_unpin=$unpinned;peek_passthrough=$ctrlSpace.received;graceful_quit=$true;checked_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content $Report
}finally{
 if($hostProcess -and -not $hostProcess.HasExited){$hostProcess.Kill()}
 $form.Close();$form.Dispose()
}
