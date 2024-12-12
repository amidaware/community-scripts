<#
.SYNOPSIS
    Fixes taskbar issues on RDS servers by resetting and reconfiguring firewall rules in the Windows Registry.

.DESCRIPTION
    This script addresses taskbar issues on Remote Desktop Services (RDS) servers. 
    It removes and recreates specific firewall-related registry keys and sets the `DeleteUserAppContainersOnLogoff` configuration. 
    A manual reboot is required after running the script.

.NOTES
    Author: SAN
    Date: ???
    #public

.CHANGELOG

.TODO
    Implement a reboot flag
    
#>


# Remove existing AppIso FirewallRules
Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\AppIso\FirewallRules" -Force

# Create new AppIso FirewallRules key
New-Item "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\AppIso\FirewallRules" -Force

# Remove existing FirewallRules
Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules" -Force

# Create new FirewallRules key
New-Item "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules" -Force

# Set DWORD DeleteUserAppContainersOnLogoff to 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy" -Name "DeleteUserAppContainersOnLogoff" -Value 1 -Type DWord


Write-Host "Registery fixed, Please reboot the device manualy"