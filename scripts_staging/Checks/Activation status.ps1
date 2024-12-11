<#
.SYNOPSIS
    Checks the Windows activation status and exits with the appropriate code.

.DESCRIPTION
    This script checks the activation status of the Windows operating system.
    It uses the WMI query to determine if Windows is activated and exits with
    status code 0 if activated, or 1 if not activated.

.NOTES
    Author: SAN
    Date : 13.11.24
    #public

.CHANGELOG

#>

$activationStatus = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey <> NULL"

if ($activationStatus.LicenseStatus -eq 1) {
    Write-Host "Windows is activated."
    exit 0
} else {
    Write-Host "Windows is not activated."
    exit 1
}
