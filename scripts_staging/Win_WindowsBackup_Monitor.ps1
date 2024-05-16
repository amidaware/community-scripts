<#
.SYNOPSIS
    Monitors and reports on the status of system backups.

.DESCRIPTION
    This script checks the status of the most recent successful backup and recent failed backups in the Windows Backup event log. It provides the date of the last successful backup and lists details of the last 20 failed backup events, including the date and error message.

.OUTPUTS
    Outputs the date of the last successful backup if available, otherwise notifies of no successful backups. Also, lists the last 20 failed backup events if any, otherwise returns an error message about no failed backups.

.NOTES
    v1.0 5/13/2024 silversword411 Initial version

#>


# Define the log name and source
$logName = "Microsoft-Windows-Backup"
$successEventId = 14
$exitCode = 0 # Default exit code

# Retrieve the most recent successful backup event
$lastSuccessfulBackupEvent = Get-WinEvent -FilterHashtable @{LogName = $logName; ID = $successEventId } | Sort-Object TimeCreated -Descending | Select-Object -First 1

# Check if a successful backup event was found
if ($lastSuccessfulBackupEvent) {
    Write-Output "Last successful backup date: $($lastSuccessfulBackupEvent.TimeCreated)"

    # Check if the last successful backup is older than 15 days
    $currentDate = Get-Date
    $timeDifference = $currentDate - $lastSuccessfulBackupEvent.TimeCreated

    if ($timeDifference.Days -gt 15) {
        Write-Output "The last successful backup is older than 15 days."
        $exitCode = 1 # Set exit code to 1
    }
}
else {
    Write-Output "No successful backup events found."
    $exitCode = 1 # Set exit code to 1
}



Write-Output "---------------------------------"

# Define the log name and source
$logName = "Microsoft-Windows-Backup"
$failureEventId = 49

# Retrieve the 20 most recent failed backup events
$recentFailedBackupEvents = Get-WinEvent -FilterHashtable @{LogName = $logName; ID = $failureEventId } | Sort-Object TimeCreated -Descending | Select-Object -First 20

# Check if there are any failed backup events
if ($recentFailedBackupEvents) {
    Write-Output "Last 20 failed backup events:"
    foreach ($event in $recentFailedBackupEvents) {
        Write-Output ("Date: " + $event.TimeCreated + ", Message: " + $event.Message)
    }
}
else {
    Write-Error "No failed backup events found."
}

# Exit script with the determined exit code
exit $exitCode
