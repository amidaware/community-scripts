# This will show how many bad login attempts you have per day on a windows machine.

$ErrorActionPreference= 'silentlycontinue'
$TimeSpan = (Get-Date) - (New-TimeSpan -Day 1)

if (Get-WinEvent -FilterHashtable @{LogName='security';ID='4625';StartTime=$TimeSpan})

{
Write-Output "There has been Bad Login events detected on your system"
Get-WinEvent -FilterHashtable @{LogName='security';ID='4625';StartTime=$TimeSpan} | Format-List TimeCreated, Id, LevelDisplayName, Message
exit 1
}

{
else 
Write-Output "No bad login events detected"
exit 0
}
