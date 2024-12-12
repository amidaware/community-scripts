<#
.SYNOPSIS
    Retrieves licensing information for installed Microsoft Office products.

.DESCRIPTION
    This script uses the `Get-CimInstance` cmdlet to query the `SoftwareLicensingProduct` class for 
    details about installed Microsoft Office products with active licenses. 

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG


#>

Get-CimInstance -ClassName SoftwareLicensingProduct | where {$_.name -like "*office*" -and $_.LicenseStatus -gt 0  }| select Name,description,LicenseStatus,ProductKeyChannel,PartialProductKey