<#
.SYNOPSIS
    Restarts the Windows Time Service, resyncs system time, and queries the current time source.

.DESCRIPTION
    This script ensures that the Windows Time Service (w32time) is restarted, the system clock is resynced with its configured time source,
    and the current time source is queried. Useful for troubleshooting time synchronization issues on a Windows system.

.NOTES
    Author: SAN
    Date: 15.11.24
    #public

.CHANGELOG 
    15.11.24 v2.0 SAN Cleanup of the code & added header

#>

Write-Host "Restarting time service..."
try {
    Restart-Service w32time -ErrorAction Stop
    Write-Host "Time service restarted successfully."
} catch {
    Write-Host "Failed to restart time service: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Waiting for 10 seconds..."
Start-Sleep -Seconds 10

Write-Host "Resyncing system time..."
try {
    w32tm /resync
    Write-Host "System time resynced successfully."
} catch {
    Write-Host "Failed to resync system time." -ForegroundColor Red
}

Write-Host "Querying time source..."
try {
    w32tm /query /source
} catch {
    Write-Host "Failed to query time source." -ForegroundColor Red
}
