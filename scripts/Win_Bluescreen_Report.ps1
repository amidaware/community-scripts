<#
.Synopsis
    Bluescreen - Reports bluescreens
.DESCRIPTION
    This script checks for Bluescreen events on your system. If a parameter is provided, it goes back that number of days to check.
.EXAMPLE
    365
.NOTES
    v1 bbrendon 2/2021
    v1.1 silversword updating with parameters 11/2021
    v1.2 dinger1986 Updated for improved filtering and structure 11/2024
#>

# Get the parameter (number of days to go back)
$DaysBack = $args[0]

# Set error handling preference
$ErrorActionPreference = 'SilentlyContinue'

# Determine the time range based on the parameter
if ($Args.Count -eq 0) {
    $StartTime = (Get-Date).AddDays(-1)
} else {
    $StartTime = (Get-Date).AddDays(-[int]$DaysBack)
}

# Retrieve Bluescreen events
$BlueScreenEvents = Get-WinEvent -FilterHashtable @{
    LogName      = 'Application';
    ID           = 1001;
    ProviderName = 'Windows Error Reporting';
    Level        = 4;
    StartTime    = $StartTime
} | Where-Object { $_.Message -like "*BlueScreen*" }

# Check and output results
if ($BlueScreenEvents) {
    Write-Output "There have been Bluescreen events detected on your system:"
    $BlueScreenEvents | Format-List TimeCreated, Id, LevelDisplayName, Message
    exit 1
} else {
    Write-Output "No Bluescreen events detected in the past $((Get-Date) - $StartTime).Days days."
    exit 0
}
