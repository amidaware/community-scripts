<#
.SYNOPSIS
    Gathers system information for licensing reporting to Microsoft.

.DESCRIPTION
    This script collects and displays key system details required for licensing reports, 
    such as OS version, build number, edition, workgroup or domain nameand the number of CPU sockets. 
    It utilizes PowerShell cmdlets like `Get-CimInstance` and `Get-WmiObject` to retrieve system data.

.NOTES
    Author: SAN
    Date: YYYY-MM-DD
    #public

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG

.TODO
    Optimize the calculation of CPU sockets for clarity and accuracy.

#>


function Get-WindowsVersion {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $osVersion = $osInfo.Version
    $osBuild = $osInfo.BuildNumber
    $osEdition = $osInfo.Caption
    
    $hostname = $env:COMPUTERNAME
    $workgroup = (Get-WmiObject Win32_ComputerSystem).Domain
    $localIP = (Test-Connection -ComputerName $hostname -Count 1).IPV4Address.IPAddressToString

    $CPU = Get-WmiObject -Class Win32_Processor
    $CPUs = 0
    $Sockets = 0

    foreach ($Processor in $CPU) {
        $CPUs++
        $Sockets += $Processor.NumberOfLogicalProcessors / $Processor.NumberOfCores
    }

    #Write-Host "Hostname: $hostname"
    Write-Host "OS: $osEdition"
    Write-Host "Workgroup/Domain: $workgroup"
    #Write-Host "Local IP Address: $localIP"
    Write-Host "Sockets: $Sockets"
}

Get-WindowsVersion