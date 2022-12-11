# Check if the system is using UEFI or legacy BIOS
if ($env:firmware_type -match "UEFI") {
    # If the system is using UEFI, check if secure boot is enabled
    $secureBootSetting = (Get-WmiObject -Class "Win32_BIOS" -Namespace "root\CIMV2").SecureBootEnabled
    if ($secureBootSetting -eq "True") {
        # If secure boot is enabled, output a message
        Write-Output "The system is using UEFI with secure boot enabled."
    }
    else {
        # If secure boot is not enabled, output a message
        Write-Output "The system is using UEFI but secure boot is not enabled."
    }
}
else {
    # If the system is not using UEFI, output a message
    Write-Output "The system is using legacy BIOS."
}