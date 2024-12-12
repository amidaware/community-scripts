<#
.SYNOPSIS
    Checks if the system is booted in Safe Mode.

.DESCRIPTION
    This script confirms the system is booted in Safe Mode and exits with a code 1. Otherwise, it indicates 
    that the system is not in Safe Mode and exits with a code 0.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    12.12.24 SAN Changed outputs

#>

# Check if the system is booted in Safe Mode
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option"
$safeModeKeyExists = Test-Path $regPath

if ($safeModeKeyExists) {
    Write-Host "KO: System is booted in Safe Mode."
    exit 1 
} else {
    Write-Host "OK: System is not booted in Safe Mode."
    exit 0  
}