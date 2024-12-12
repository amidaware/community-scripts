<#
.SYNOPSIS
    Retrieves and formats the installation date of the operating system.

.DESCRIPTION
    This script fetches the installation date of the current Windows operating system and 
    formats it into a "dd/MM/yyyy" format, then outputs the formatted date to the console.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG


#>


$osInfo = Get-WmiObject Win32_OperatingSystem
$installDate = $osInfo.ConvertToDateTime($osInfo.InstallDate)
$formattedDate = $installDate.ToString("dd/MM/yyyy")
Write-Host "$formattedDate"