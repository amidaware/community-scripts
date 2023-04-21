# Test Windows LAPS has been rotating passwords in line with your group policy setting
# from Yasd in Discord

$e = Get-WinEvent -LogName 'Microsoft-Windows-LAPS/Operational' -FilterXPath '*[System[(EventID=10021)]]' -MaxEvents 1

if ($e) { $days = ($e.Message | Select-String -Pattern "Password age in days: (\d+)").Matches.Groups[1].Value }
else { Write-Output "No LAPS policy detected"; exit 0 }

$e = Get-WinEvent -LogName 'Microsoft-Windows-LAPS/Operational' -FilterXPath '*[System[(EventID=10020)]]' -MaxEvents 1

if ($e -and ($e.TimeCreated.AddDays($days) -lt $(Get-Date))) { Write-Output "Last successful LAPS password rotation was more than $days days ago"; exit 1 }