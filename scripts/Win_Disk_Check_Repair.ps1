<#
.SYNOPSIS
    A PowerShell script to repair a volume using the Repair-Volume cmdlet.

.DESCRIPTION
    This script uses the Repair-Volume cmdlet to scan and/or repair a specified volume
    based on the provided DriveLetter. By default, the script performs an online scan.
    The user can choose to perform an offline scan or a spot fix on the volume.

.PARAMETER DriveLetter
    Specifies the drive letter of the volume to be scanned/repaired.

.PARAMETER Offline
    When specified, the script performs an offline scan on the volume.

.PARAMETER SpotFix
    When specified, the script performs a spot fix on the volume.

.EXAMPLE
    -DriveLetter "C"

    Performs an online scan of the volume with the drive letter "C"

.EXAMPLE
    -DriveLetter "C" -Offline

    Schedules an offline scan of the volume with the drive letter "C" upon next reboot

.EXAMPLE
    -DriveLetter "C" -SpotFix

    Performs a spot fix on the volume with the drive letter "C"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DriveLetter,

    [switch]$Offline,
    [switch]$SpotFix
)

# Perform the requested operation(s) on the volume
if ($Offline) {
    Write-Output "Performing offline scan on volume $DriveLetter`:"
    Repair-Volume -DriveLetter $DriveLetter -OfflineScanAndFix
}
elseif ($SpotFix) {
    Write-Output "Performing spot fix on volume $DriveLetter`:"
    Repair-Volume -DriveLetter $DriveLetter -SpotFix
}
else {
    Write-Output "Performing online scan on volume $DriveLetter`:"
    Repair-Volume -DriveLetter $DriveLetter -Scan
}
