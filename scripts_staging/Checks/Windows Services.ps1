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
    Recheck the list of services for any that should be monitored (e.g., ShellHWDetection).
    Add "IgnoredServices" env to "ignoredPatternSuffix" also


.CHANGELOG
    28.10.24 SAN Removed ignored output without the debug flag.
    28.10.24 SAN cleanup documentation.
    21.01.25 SAN Code cleanup
    27.03.25 SAN added kerberos local key to default
    31.03.25 SAN Added a new patern for ignroring user services (servicename_XXX) while keeping their system counterpart inculded
    17.07.25 SAN Added InventorySvc it is expected to randomly turn on and off 
#>


# Define a generic list of service names to be ignored by default
$ignoredByDefault = @(
    "Software Protection",
    "Remote Registry",
    "State Repository Service",
    "Service Google Update",
    "Clipboard User Service",
    "Service Brave Update",
    "Google Update Service",
    "Windows Modules Installer", # Unsure if this one should be monitored
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
    "TrustedInstaller", # Frequently failing; unclear if actionable
    "MSExchangeNotificationsBroker",
    "tiledatamodelsvc",
    "BITS",
    "CDPSvc",
    "AGSService",
    "ShellHWDetection", # Frequently failing; unclear if actionable
    "DropboxUpdater",
    "LocalKDC", # https://learn.microsoft.com/en-us/answers/questions/2136070/windows-server-2025-kerberos-local-key-distributio
    "InventorySvc" #https://learn.microsoft.com/en-us/answers/questions/2258983/inventory-and-compatibility-appraisal-service-in-m
)

# Define a list of services to ignore that match the pattern "nameoftheservice_xxxx"
$ignoredPatternSuffix = @(
    "CDPUserSvc",
    "OneSyncSvc",
    "WpnUserService"
)

# Get any additional services to ignore from the environment variable
$addonsToIgnoredList = [Environment]::GetEnvironmentVariable('IgnoredServices')
if (-not [string]::IsNullOrEmpty($addonsToIgnoredList)) {
    $additionalServices = $addonsToIgnoredList -split ','
    $ignoredByDefault += $additionalServices
}

# Combine the regular ignored services and the ones with suffix _xxxx pattern
$ignoredPattern = ($ignoredByDefault | ForEach-Object { [regex]::Escape($_) }) -join '|'
$ignoredPatternSuffixRegex = ($ignoredPatternSuffix | ForEach-Object { [regex]::Escape($_) + '_\w+' }) -join '|'

# Get services with Automatic start type or Automatic (Delayed Start) that are not running
$servicesToCheck = Get-Service | Where-Object { ($_.StartType -eq 'Automatic' -or $_.StartType -eq 'Automatic (Delayed Start)') -and $_.Status -ne 'Running' }

# Initialize arrays to store services that need attention and services that were stopped but ignored
$servicesNeedingAttention = @()
$ignoredStoppedServices = @()

# Check the status of each service and categorize based on ignore patterns
foreach ($service in $servicesToCheck) {
    # Ignore services that match the defined patterns (both regular and suffixed with _xxxx)
    if ($service.DisplayName -notmatch $ignoredPattern -and $service.ServiceName -notmatch $ignoredPattern -and $service.ServiceName -notmatch $ignoredPatternSuffixRegex) {
        $servicesNeedingAttention += $service
    } else {
        $ignoredStoppedServices += $service
    }
}

# Check if debug mode is enabled via the environment variable
$enableDebugValue = [System.Environment]::GetEnvironmentVariable("enabledebugscript")
$debugEnabled = $enableDebugValue -ne $null -and [System.Boolean]::Parse($enableDebugValue)

# Display debug message if enabled
if ($debugEnabled) {
    Write-Host "Debug mode is enabled."
}

# Display the results based on the service statuses
if ($servicesNeedingAttention.Count -eq 0) {
    if (-not $debugEnabled) {
        Write-Host "All required services are running."
    }

    if ($ignoredStoppedServices.Count -ne 0 -and $debugEnabled) {
        Write-Host "The following services were stopped but are ignored:"
        foreach ($service in $ignoredStoppedServices) {
            Write-Host "$($service.DisplayName) ($($service.ServiceName))"
        }
    }

    Exit 0

} else {
    Write-Host "The following services need attention:"
    foreach ($service in $servicesNeedingAttention) {
        Write-Host "$($service.DisplayName) ($($service.ServiceName))"
    }

    Exit 1
}
