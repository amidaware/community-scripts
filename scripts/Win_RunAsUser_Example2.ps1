<#
.SYNOPSIS
    This is an example script for getting logged in username for RunAsUser scripts. To be run from SYSTEM (not TRMM RunAsUser)

.DESCRIPTION
    Fully functional example for RunAsUser, including getting return data and exit 1 from Userland

.NOTES
    V1.0 
#>

$currentuser = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]

If (!$currentuser) {    
    Write-Output "Noone currently logged in"
} else {
    Write-Output "Currently logged in user is: $currentuser"}