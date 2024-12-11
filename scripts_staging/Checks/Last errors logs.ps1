<#
.SYNOPSIS
    This script retrieves and processes error events from the Windows Event Log within the last 48 and 12 hours.

.DESCRIPTION
    This script is useful for monitoring and alerting on error events in the Windows Event Log.
    The script processes error logs from the 'System' log only, only critical errors are counted and displayed.

    1. Retrieves the last 20 error events from the 'System' log in the last 48 hours, excluding specified event IDs.
    2. Counts and displays the number of error events found in the last 48 hours (after filtering out ignored events).
    3. Retrieves error events from the last 12 hours and checks if there are 4 or more errors.
    4. If 4 or more errors are found in the last 12 hours, the script exits with an error code (1).
    5. If fewer than 4 errors are found, the script exits with a success code (0).

.NOTES
    Author: SAN
    Date: 24.10.2024
    #public

.CHANGELOG
    04.12.24 SAN added id to ignore in comma separeted variable

.TODO
    Set 20 Error Events and 48 hours in vars same for 4 and 12

#>
# Define the time ranges
$start48h = (Get-Date).AddHours(-48)
$start12h = (Get-Date).AddHours(-12)

# Define a list of event IDs to ignore
$ignoredEventIds = @(10016, 10016)

#10016 safe to ignore https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom

# Retrieve the last 20 error events in the last 48 hours
$errors48h = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$start48h} -MaxEvents 20 -ErrorAction SilentlyContinue

# Filter out events with IDs in the ignored list
$filteredErrors48h = $errors48h | Where-Object { $ignoredEventIds -notcontains $_.Id }

# Count of errors found in the last 48 hours (after ignoring specified event IDs)
$errorCount = if ($filteredErrors48h) { $filteredErrors48h.Count } else { 0 }

if ($errorCount -gt 0) {
    # Output the number of errors found
    Write-Output "$errorCount error(s) found recently."
}

# If errors are found, display them
if ($errorCount -gt 0) {
    Write-Output "Last 20 Error Events in the last 48 hours (excluding ignored event IDs):"
    $filteredErrors48h | ForEach-Object {
        Write-Output "TimeCreated: $($_.TimeCreated)"
        Write-Output "Event ID: $($_.Id)"
        Write-Output "Message: $($_.Message)"
        Write-Output "----------------------------------------"
    }
}

# Retrieve the error events from the last 12 hours
$errors12h = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$start12h} -ErrorAction SilentlyContinue

# Filter out events with IDs in the ignored list for the 12-hour check
$filteredErrors12h = $errors12h | Where-Object { $ignoredEventIds -notcontains $_.Id }

# Check if there are 4 or more errors in the last 12 hours (excluding ignored event IDs)
if ($filteredErrors12h -and $filteredErrors12h.Count -ge 4) {
    Write-Output "Error: 4 or more error events found in the last 12 hours."
    exit 1
} else {
    if (!$filteredErrors12h) {
        Write-Output "No error events found in the last 12 hours."
    } else {
        Write-Output "OK: Less than 4 error events found in the last 12 hours."
    }
    exit 0
}
