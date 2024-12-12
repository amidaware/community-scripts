<#
.SYNOPSIS
    Initiates an Azure AD synchronization cycle.

.DESCRIPTION
    This script checks if the ADSync module is loaded, and if not, imports it. 
    It then triggers a delta synchronization cycle using the `Start-ADSyncSyncCycle` command.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    12.12.24 Simple polish
    
#>

# Check if the ADSync module is already imported, if not, import it
if (-not (Get-Module -Name 'ADSync' -ErrorAction SilentlyContinue)) {
    Write-Host "Importing the Azure AD Sync module..."
    Import-Module ADSync
}

try {
    Write-Host "Starting Azure AD Delta Synchronization..."
    Start-ADSyncSyncCycle -PolicyType Delta
    Write-Host "Azure AD sync initiated successfully!"
    Write-Host "Please check the Azure AD Connect Health for status."

}
catch {
    Write-Host "An error occurred while initiating the Azure AD sync: $_"
    Write-Host "Please check the Azure AD Connect logs for more details."
}
