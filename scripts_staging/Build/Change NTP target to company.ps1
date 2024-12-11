<#
.SYNOPSIS
    Configures the system's time synchronization with an NTP server if the computer is not part of a domain or is a Domain Controller.

.DESCRIPTION
    This script checks the domain membership status of the machine. 
    If the device is either not part of a domain or is a Domain Controller, it configures the Windows Time service (`w32time`) to synchronize with an NTP server specified in the `NTPTARGET` environment variable. The script updates registry settings related to time synchronization, ensures the correct time zone is set, and forces a time resynchronization.

.PARAMETER NTPTARGET
    The NTP server address that the machine will use for time synchronization. 
    This can be specified through the environment variable `NTPTARGET`.

.EXAMPLE
    NTPTARGET=pool.ntp.org
    This will configure the system to synchronize its time with `pool.ntp.org`.

.NOTES
    Author: SAN
    Date: 01.01.2024
    #public

.CHANGELOG


#>



try {
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $domain = $computerSystem.PartOfDomain
    $isDomainController = $computerSystem.DomainRole -eq 4 -or $computerSystem.DomainRole -eq 5
} catch {
    Write-Host "Error determining domain membership status. Exiting script."
    exit
}

$ntpTarget = $env:NTPTARGET
if (-not $ntpTarget) {
    Write-Host "NTPTARGET environment variable is not set. Exiting script."
    exit
}

if (-not $domain -or $isDomainController) {
    Write-Host "Device is not a member of a domain or is a Domain Controller. Proceeding with time configuration."

    Start-Service w32time

    w32tm /config /manualpeerlist:"$ntpTarget,0x8" /syncfromflags:manual /reliable:yes /update

    try {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "SpecialPollInterval" -Value 3600 -PropertyType DWord -Force
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers" -Name "0" -Value "$ntpTarget" -PropertyType String -Force
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers" -Name "(default)" -Value "0" -PropertyType String -Force
    } catch {
        Write-Host "Error setting registry values. Exiting script."
        exit
    }

    Set-Service W32Time -StartupType "Automatic"

    Stop-Service w32time
    Start-Service w32time
    Set-TimeZone -Name "W. Europe Standard Time"

    w32tm /resync

    Write-Host "Time configuration done."
} else {
    Write-Host "Device is a member of a domain and is not a Domain Controller. Skipping time configuration."
}