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
    09.04.25 SAN move to Get-CimInstance and other improvements

#>


try {
    $activationStatus = Get-CimInstance -Query "SELECT * FROM SoftwareLicensingProduct WHERE LicenseStatus = 1 AND PartialProductKey IS NOT NULL" -ErrorAction Stop

    if ($activationStatus) {
        foreach ($product in $activationStatus) {
            Write-Host "OK: Activated - $($product.Name) [$($product.Description)]"
        }
        exit 0
    } else {
        Write-Host "KO: Windows is not activated."
        exit 1
    }
} catch {
    Write-Host "ERROR: Failed to check activation status. $_"
    exit 1
}

