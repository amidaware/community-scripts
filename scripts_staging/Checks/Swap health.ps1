<#
.SYNOPSIS
    This script checks the virtual memory settings on a Windows system, comparing them against recommended guidelines. 

.DESCRIPTION
    This script retrieves information about physical and virtual memory on the system, calculates recommended minimum and maximum virtual memory sizes, 
    and compares them with the settings configured on the system. It provides warnings and errors if the configured settings do not meet the recommended 
    criteria.

.NOTES
    Author: SAN
    Date: 01.01.24
    Usefull links:
        https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows
    #public

.TODO
    Implement fully the recomendations of the script
    
.CHANGELOG
    v1.1 9/12/2024 silversword411 Adding GB to output
    v1.2 10/30/2024 SAN change output layout for readability

#>


# Helper function to convert bytes to gigabytes
function ConvertTo-GB {
    param ([double]$bytes)
    return [math]::Round($bytes / 1GB, 2)
}

# Get the virtual memory information
$virtualMemoryInfo = Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem"

# Extract the Max Size and Available values
$MaxSize = $virtualMemoryInfo.TotalVirtualMemorySize * 1024
$Available = $virtualMemoryInfo.FreeVirtualMemory * 1024

# Get the minimum size set on the system
$minimumSize = $virtualMemoryInfo.TotalVisibleMemorySize * 1024

# Calculate the minimum size based on RAM ÷ 8, max 32 GB
$physicalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
$calculatedMinimumSize = [Math]::Min(($physicalMemory / 8), 32GB)

# Calculate the max size based on 3 times the RAM or 4 GB, whichever is larger
$calculatedMaxSize = [Math]::Max(($physicalMemory * 3), 4GB)

# Required Available memory (10% of Max Size)
$requiredAvailable = $MaxSize * 0.05


if ($Available -ge $requiredAvailable) {
    Write-Output "Available meets the requirement."
} else {
    Write-Output "Available does not meet the requirement (should be at least 10% of Max Size). (Error)"
    $host.SetShouldExit(2)
}
Write-Output ("Available: {0} GB" -f (ConvertTo-GB $Available))
Write-Output ("Required Available: {0} GB" -f (ConvertTo-GB $requiredAvailable))
Write-Output "---------------"

if ($minimumSize -ge $calculatedMinimumSize) {
    Write-Output "Minimum Size meets the requirement."
} else {
    Write-Output "Minimum Size does not meet the requirement (should be at least RAM divided by 8, max 32 GB). (Warn)"
    #$host.SetShouldExit(1)
}
Write-Output ("Minimum Size set on the system: {0} GB" -f (ConvertTo-GB $minimumSize))
Write-Output ("Calculated Minimum Size: {0} GB" -f (ConvertTo-GB $calculatedMinimumSize))
Write-Output "---------------"

if ($MaxSize -ge $calculatedMaxSize) {
    Write-Output "Max Size meets the requirement."
} else {
    Write-Output "Max Size does not meet the requirement (should be at least 3 times the RAM or 4 GB, whichever is larger). (Warn)"
    #$host.SetShouldExit(1)
}
Write-Output ("Max Size: {0} GB" -f (ConvertTo-GB $MaxSize))
Write-Output ("Calculated Max Size: {0} GB" -f (ConvertTo-GB $calculatedMaxSize))
