<#
.SYNOPSIS
    This script retrieves Windows services that are set to start automatically (including delayed start) but are not currently running,
    and optionally starts those services based on the value of an environment variable.

.DESCRIPTION
    The script checks for the environment variable "START_SERVICES". If this variable is set to "true", the script will attempt to start 
    all services that are configured to start automatically (including delayed start) but are not currently running. It displays the 
    list of such services in a formatted table for the user. If the environment variable is not set to "true", the script will only
    display the list of services without starting them.

.PARAMETER None
    "START_SERVICES" environment variable to determine whether to start the services.

.EXEMPLE
    START_SERVICES=true

.NOTES
    Author:Dave Long <dlong@cagedata.com>
    Date: 2021-05-12
    #public

.Changelog 
    02.12.24 SAN Full code refactorisation

#>

# Check for an environment variable (e.g., "START_SERVICES") to determine if services should be started
$StartServices = $false
if ($env:START_SERVICES -eq "true") {
    $StartServices = $true
    Write-Output "Start Services enabled"
}

# Retrieve services that are set to start automatically (including delayed) but are not currently running
$servicesToStart = Get-Service | Where-Object {
    $_.StartType -in @("Automatic", "AutomaticDelayedStart") -and
    $_.Status -ne "Running"
}

# Display the services in a formatted table
$servicesToStart | Format-Table -AutoSize

# Start the services if the environment variable is set to true
if ($StartServices) {
    foreach ($service in $servicesToStart) {
        try {
            Start-Service -Name $service.Name -ErrorAction Stop
            Write-Output "Started service: $($service.Name)"
        } catch {
            Write-Warning "Failed to start service: $($service.Name). Error: $_"
        }
    }
} else {
    Write-Output "Services will not be started. Set environment variable 'START_SERVICES' to 'true' to enable this."
}
