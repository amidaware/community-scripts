<#
.Synopsis
    Defender - Status Report
.DESCRIPTION
    This will check Event Log for Windows Defender Malware and Antispyware reports, otherwise will report as Healthy. By default if no command parameter is provided it will check the last 1 day (good for a scheduled daily task). 
    If a number is provided as a command parameter it will search back that number of days back provided (good for collecting all AV alerts on the computer).
.EXAMPLE
    365
.NOTES
    v1 dinger initial release 2021
    v1.1 bdrayer Adding full message output if items found
    v1.2 added extra event IDs for ASR monitoring suggested by SDM216
#>

$param1 = $args[0]

$ErrorActionPreference = 'silentlycontinue'
if ($Args.Count -eq 0) {
    $TimeSpan = (Get-Date) - (New-TimeSpan -Day 1)
}
else {
    $TimeSpan = (Get-Date) - (New-TimeSpan -Day $param1)
}

if (Get-WinEvent -FilterHashtable @{LogName = 'Microsoft-Windows-Windows Defender/Operational'; ID = '1122', '1012', '1009', '1119', '1118', '1008', '1006', '1116', '1121', '1015', '1124', '1123', '1160'; StartTime = $TimeSpan }) 
{
    Write-Output "Virus Found or Issue with Defender"
    Get-WinEvent -FilterHashtable @{LogName = 'Microsoft-Windows-Windows Defender/Operational'; ID = '1122', '1012', '1009', '1119', '1118', '1008', '1006', '1121', '1116', '1015', '1124', '1123', '1160'; StartTime = $TimeSpan } | Select-Object -ExpandProperty Message -First 1
    exit 1
}


else 
{
    Write-Output "No Virus Found, Defender is Healthy"
    Get-WinEvent -FilterHashtable @{LogName = 'Microsoft-Windows-Windows Defender/Operational'; ID = '1150', '1001'; StartTime = $TimeSpan }
    exit 0
}
