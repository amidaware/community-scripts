# Check if the system is using UEFI or legacy BIOS
if ([System.Management.ManagementBaseObject]::ReferenceEquals(
    (Get-WmiObject -Class "Win32_BIOS" -Namespace "root\CIMV2").BIOSVersion,
    (Get-WmiObject -Class "Win32_BIOS" -Namespace "root\CIMV2").SMBIOSBIOSVersion
    )) {
    Write-Output "The system is using UEFI"

    # Check if Secure Boot is enabled
    $secureBootSetting = (Get-WmiObject -Class "Win32_BIOS" -Namespace "root\CIMV2").SecureBootEnabled
    if ($secureBootSetting -eq "True") {
        Write-Output "Secure Boot is enabled"
    }
    else {
        Write-Output "Secure Boot is not enabled"
    }
}
else {
    Write-Output "The system is using legacy BIOS"
}