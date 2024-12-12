<#
.SYNOPSIS
    Retrieves and displays system uptime and shutdown event information.

.DESCRIPTION
    This script retrieves the last boot time of the system, calculates the uptime (in days, hours, and minutes),
    and retrieves the most recent shutdown event from the system's event log (EventID 1074).

.NOTES
    Author: SAN
    Date: 03.10.24
    #public

.CHANGELOG
    SAN 12.12.24 Code cleanup
        
#>

$lastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $lastBootTime
$shutdownEvent = Get-WinEvent -LogName System -FilterXPath "*[System/EventID=1074]" | Select-Object -First 1

Write-Output "==========================="
Write-Output "                  Last Reboot Information"
Write-Output "==========================="

Write-Output "Last Boot Time                 : $($lastBootTime)"
Write-Output "Uptime (since last boot)       : $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
Write-Output "Event Log Time                 : $($shutdownEvent.TimeCreated)"

Write-Output "==========================="
Write-Output "                    All Event Properties"
Write-Output "==========================="

Write-Output "Initiating Process/Executable  : $($shutdownEvent.Properties[0].Value)"
Write-Output "Initiating Machine             : $($shutdownEvent.Properties[1].Value)"
Write-Output "Shutdown Reason                : $($shutdownEvent.Properties[2].Value)"
Write-Output "Shutdown Code                  : $($shutdownEvent.Properties[3].Value)"
Write-Output "Shutdown Type                  : $($shutdownEvent.Properties[4].Value)"
Write-Output "Additional Info                : $($shutdownEvent.Properties[5].Value)"
Write-Output "User Account                   : $($shutdownEvent.Properties[6].Value)"
