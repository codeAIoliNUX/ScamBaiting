# seed.ps1 - run ONCE inside the golden VM (admin PowerShell). All data is synthetic.
param(
  [string]$First='Margaret', [string]$Last='Hollis', [string]$City='Omaha, NE',
  [string]$Tz='Central Standard Time', [string]$Bank='Prairie Mutual Credit Union',
  [int]$Balance=18432
)
$ErrorActionPreference = 'Stop'
Set-TimeZone -Id $Tz
powercfg /change standby-timeout-ac 0; powercfg /change monitor-timeout-ac 0
Rename-Computer -NewName ("{0}-PC" -f $First.ToUpper()) -Force

$docs = [Environment]::GetFolderPath('MyDocuments'); $desk = [Environment]::GetFolderPath('Desktop')
New-Item -ItemType Directory -Force "$docs\Taxes","$docs\Medical","$docs\Photos" | Out-Null
$bal = [string]::Format('{0:C2}', $Balance)

@"
$First $Last - $City
SSN: 987-65-4321        (reserved/invalid range)
Card: 4111 1111 1111 1111  (public test number)
$Bank online login: $($First.ToLower())$($Last.ToLower())1948 / Sunshine#12
"@ | Set-Content "$docs\important stuff.txt"

"Taxes 2025 - waiting on 1099 from $Bank. Ask Danny (grandson)." | Set-Content "$docs\Taxes\notes.txt"
"Appointment: Dr. Patel, 2nd Tuesday, bring Medicare card."     | Set-Content "$docs\Medical\appointments.txt"

@"
<!-- synthetic decoy page: no real bank, no real data -->
<html><head><title>$Bank - Online Banking</title>
<style>body{font-family:Arial;max-width:520px;margin:40px auto}input{display:block;margin:8px 0;padding:6px;width:100%}</style></head>
<body><h2>$Bank</h2>
<form onsubmit="document.getElementById('m').innerText='Verifying your identity... please wait (this can take several minutes)';return false">
<input placeholder="Username"><input type="password" placeholder="Password"><button>Sign in</button></form>
<p id="m"></p><hr><p>Checking ****4821: <b>$bal</b></p></body></html>
"@ | Set-Content "$desk\$Bank Online.html"

Write-Host "Seeded $First $Last ($City). Next: install AnyDesk, do NOT install spice-guest-tools, shut down, chmod a-w the golden qcow2 on the host."
