<#
.SYNOPSIS
    This script calculates the uptime of a computer and compares it to a specified maximum time.

.DESCRIPTION
    The script retrieves the LastBootUpTime of the computer and calculates the current uptime. 
    If the uptime exceeds the maximum time, the script exits with an exit code of 1.
    If the uptime is within the allowed range, the script exits with an exit code of 0.

.PARAMETER MaxTime
    Specifies the maximum allowed uptime in days.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.TODO
    move var to env

.CHANGELOG
    12.12.24 SAN Changed outputs

#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Specify the maximum allowed uptime in days.")]
    [int]$MaxTime
)

# Calculate the uptime
$uptime = (Get-Date) - (Get-CimInstance -Class Win32_OperatingSystem).LastBootUpTime
$uptimeDays = $uptime.Days
$uptimeTimeSpan = $uptime.ToString("hh\:mm\:ss")
$formattedUptime = "{0} days, {1}" -f $uptimeDays, $uptimeTimeSpan

# Compare the uptime with the maximum time
if ($uptimeDays -gt $MaxTime) {
    Write-Output "The computer has an uptime of $formattedUptime."
    Write-Output "The computer has an uptime greater than $MaxTime days."
    exit 1
} else {
    Write-Output "OK: Uptime is not above max"
    #Write-Output "The computer has an uptime of $formattedUptime."
    #Write-Output "The computer has an uptime lower than $MaxTime days."
    exit 0
}