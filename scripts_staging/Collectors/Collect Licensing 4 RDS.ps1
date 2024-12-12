<#
.SYNOPSIS
    Checks if the Remote Desktop Services role is installed and retrieves RDS license key pack details.

.DESCRIPTION
    This script verifies whether the Remote Desktop Services role is installed on the local machine. 
    If installed, it retrieves information about RDS license key packs, including details such as product version, 
    license type, total licenses, available licenses, and issued licenses. 

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.TODO
    Extend reporting to include CAL types and expiration details.
#>


try {
    # Check if the Remote Desktop Services role is installed
    $rdsRoleInstalled = Get-Service -Name TermServLicensing -ErrorAction Stop
    # If the service is not installed, display a message and return
    if ($rdsRoleInstalled -eq $null -or $rdsRoleInstalled.Installed -eq $false) {
        #"TermServLicensing service is not installed."
        return
    }
    # Get information about RDS license key packs
    Get-WmiObject Win32_TSLicenseKeyPack | 
        Where-Object { $_.ProductVersion -like "*Windows Server*" } |
        Select-Object PSComputerName, KeyPackId, ProductVersion, TypeAndModel, TotalLicenses, AvailableLicenses, IssuedLicenses 
} catch {
    # If an error occurs, display the error message
    #"Error: $_"
}