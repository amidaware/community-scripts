<#
    .SYNOPSIS
    Check for errors in Cloud Backup Mars and returns results.

    .DESCRIPTION
    This script checks for errors in the CloudBackup/Operational log on all local network adapters for the past 24 hours, and returns the results. If errors are found, the script outputs "Cloud Backup Mars Ended with Errors" and displays the relevant log events. If no errors are found, the script outputs "Cloud Backup Mars Backup Is Working Correctly" and displays the relevant log events.

    .NOTES
    Version: 1.0 
#>

$ErrorActionPreference = 'silentlycontinue'
$TimeSpan = (Get-Date) - (New-TimeSpan -Day 1)

##Check for Errors in Backup
if (Get-WinEvent -FilterHashtable @{LogName = 'CloudBackup/Operational'; ID = '11', '18'; StartTime = $TimeSpan }) {
    Write-Host "Cloud Backup Mars Ended with Errors"
    Get-WinEvent -FilterHashtable @{LogName = 'CloudBackup/Operational'; ID = '1', '14', '11', '18', '16'; StartTime = $TimeSpan }
    exit 1
}
else {
    Write-Host "Cloud Backup Mars Backup Is Working Correctly"
    Get-WinEvent -FilterHashtable @{LogName = 'CloudBackup/Operational'; ID = '1', '14', '16' }
    exit 0
}
