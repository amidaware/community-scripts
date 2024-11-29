<#
.SYNOPSIS
    Checks the status of services and makes sure all the damn required services are started, including any others you throw in through
    an environment variable.

.DESCRIPTION
    This script checks for services with automatic or delayed start that are just sitting there not running. It compares those with a list 
    of ignored services, including any additional ones you set in the "IgnoredServices" environment variable. No need for separate checks, 
    this script will tell you which ones need attention so you can get your shit together and fix it.

.NOTES
    Author: SAN

.TODO
    Recheck the list of services for any that should be monitored like ShellHWDetection
    cleanup and streamline the output with a debug flag

.CHANGELOG 28.10.24 SAN Removed ignored output without flag

#>


# Define a list of partial display names to be ignored in the check
$ignoredPartialDisplayNames = @(
    "Software Protection",
    "Remote Registry",
    "State Repository Service",
    "Service Google Update",
    "Clipboard User Service",
    "Service Brave Update",
    "Google Update Service",
    "Windows Modules Installer", #not sure about this one if we should monitor it or not
    "Downloaded Maps Manager",
    "Windows Biometric Service",
    "RemoteRegistry",
    "edgeupdate",
    "brave",
    "gupdate",
    "MapsBroker",
    "WbioSrvc",
    "cbdhsvc",
    "GoogleUpdater",
    "sppsvc",
    "SharePoint Migration Service",
    "dbupdate",
    "TrustedInstaller", #this one is strange it was failing on a lot of devices but no idea if we should fix it.
    "MSExchangeNotificationsBroker",
    "tiledatamodelsvc",
    "BITS",
    "CDPSvc",
    "AGSService",
    "ShellHWDetection" #this one is strange it was failing on a lot of devices but no idea if we should fix it.

)

# Check if "IgnoredServices" environment variable exists and add those services to the ignore list
$envIgnoredServices = [Environment]::GetEnvironmentVariable('IgnoredServices')
if (-not [string]::IsNullOrEmpty($envIgnoredServices)) {
    $additionalIgnoredServices = $envIgnoredServices -split ','
    $ignoredPartialDisplayNames += $additionalIgnoredServices
}

# Convert ignored partial display names to a regular expression pattern
$ignoredPattern = ($ignoredPartialDisplayNames | ForEach-Object { [regex]::Escape($_) }) -join '|'

# Get services with automatic start type or Automatic (Delayed Start) that are not running
$servicesToCheck = Get-Service | Where-Object { ($_.StartType -eq 'Automatic' -or $_.StartType -eq 'Automatic (Delayed Start)') -and $_.Status -ne 'Running' }

# Initialize arrays to store services that need attention and services that were stopped but ignored
$servicesToStart = @()
$ignoredStoppedServices = @()

# Check the status of each service
foreach ($service in $servicesToCheck) {
    # Check if the display name or service name matches the ignored pattern
    if ($service.DisplayName -notmatch $ignoredPattern -and $service.ServiceName -notmatch $ignoredPattern) {
        # Add the service to the list of services to start
        $servicesToStart += $service
    }
    else {
        # Add the service to the list of ignored stopped services
        $ignoredStoppedServices += $service
    }
}

# Check if enabledebug environment variable is set to true
$enableDebugValue = [System.Environment]::GetEnvironmentVariable("enabledebugscript")
$debugEnabled = $enableDebugValue -ne $null -and [System.Boolean]::Parse($enableDebugValue)


if ($debugEnabled) {
    Write-Host "Debug enabled"
}
# Display the results
if ($servicesToStart.Count -eq 0) {
    if (-not $debugEnabled) {
        Write-Host "All required services are running."
    }

    if ($ignoredStoppedServices.Count -ne 0 -and $debugEnabled) {
        Write-Host "The following services were stopped but ignored:"
        foreach ($service in $ignoredStoppedServices) {
            Write-Host "$($service.DisplayName) ($($service.ServiceName))"
        }
    }
    Exit 0
}
else {
    Write-Host "The following services need attention:"
    foreach ($service in $servicesToStart) {
        Write-Host "$($service.DisplayName) ($($service.ServiceName))"
    }
    Write-Host "Run the script 'Ensure all services with startup type Automatic are running' before trying to troubleshoot"
    Exit 1
}
