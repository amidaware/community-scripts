<#
.SYNOPSIS
    Retrieves and displays the domain or workgroup name of the computer.

.DESCRIPTION
    This script checks if the computer is part of a domain or a workgroup. 
    If the computer is part of a domain, it outputs the domain name. 
    Otherwise, it outputs the workgroup name.

.NOTES
    Author: SAN
    Date: 01.01.24 
    #public

.CHANGELOG
    

#>

# Check if the computer is a member of a domain or workgroup
$computerInfo = Get-WmiObject Win32_ComputerSystem

if ($computerInfo.PartOfDomain -eq $true) {
    Write-Host "D: $($computerInfo.Domain)"
} else {
    $workgroupName = $computerInfo.Workgroup
    Write-Host "W: $workgroupName"
}