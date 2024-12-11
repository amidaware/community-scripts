<#
.SYNOPSIS
    Checks the status of services with automatic or delayed start and identifies those that are not running. 
    Excludes services from a predefined ignore list and any additional ones specified.

.DESCRIPTION
    This script evaluates services configured with an automatic or delayed start and identifies those that are not running. 
    It compares these against a list of ignored services, including any specified via the "IgnoredServices" env variable. 

.EXEMPLE
    IgnoredServices=service1,service2,service3
    IgnoredServices=Windows update
    enabledebugscript=true

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.TODO
    - Recheck the list of services for any that should be monitored (e.g., ShellHWDetection).

.CHANGELOG
    28.10.24 SAN - Removed ignored output without the debug flag.
    28.10.24 SAN - cleanup documentation.

#>



# Define a generic list of services names to be ignored by the check
$ignoredPartialDisplayNames = @(
    "Software Protection",
    "Remote Registry",
    "State Repository Service",
    "Service Google Update",
    "Clipboard User Service",
    "Service Brave Update",
    "Google Update Service",
    "Windows Modules Installer", # not sure about this one if we should monitor it or not
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
    "TrustedInstaller", # this one is strange it was failing on a lot of devices but no idea if it should or could be fixed
    "MSExchangeNotificationsBroker",
    "tiledatamodelsvc",
    "BITS",
    "CDPSvc",
    "AGSService",
    "ShellHWDetection" # this one is strange it was failing on a lot of devices but no idea if it should or could be fixed

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
    } else {
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

} else {
    Write-Host "The following services need attention:"
    foreach ($service in $servicesToStart) {
        Write-Host "$($service.DisplayName) ($($service.ServiceName))"
    }

    Exit 1

}
