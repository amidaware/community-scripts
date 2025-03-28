<#
.SYNOPSIS
    This script checks for Windows services running under unexpected system accounts.

.DESCRIPTION
    The script retrieves all Windows services and identifies any that are running under system accounts other than 'NT AUTHORITY\LOCAL SERVICE' or 'NT AUTHORITY\NETWORK SERVICE'.
    It also filters services that have an automatic start mode. If any such services are found, they are displayed in a formatted table, including the username running the service, and the script exits with code 1.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG

#>

$allowedAccounts = @(
    "NT AUTHORITY\\LOCAL SERVICE",
    "NT AUTHORITY\\NETWORK SERVICE",
    "LocalSystem",
    "NT AUTHORITY\LocalService",
    "NT AUTHORITY\NETWORKSERVICE"


)

$found = $false
$services = @()

# Get services
Get-WmiObject Win32_Service | ForEach-Object {
    $service = $_
    if ($service.StartMode -eq "Auto" -and $service.StartName -notin $allowedAccounts) {
        $services += [PSCustomObject]@{
            Name = $service.Name
            DisplayName = $service.DisplayName
            StartName = $service.StartName
            State = $service.State
            Username = $service.StartName
        }
        $found = $true
    }
}

# If any unexpected services are found, display them in one table and exit with code 1
if ($found) {
    $services | Format-Table -AutoSize
    exit 1
}
