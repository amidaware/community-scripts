<#
.SYNOPSIS
   Retrieves BitLocker recovery information for a specified drive.

.DESCRIPTION
   The Get-BitLockerRecoveryInfo function retrieves BitLocker recovery information for a specified drive. If the -KeyOnly parameter is provided, it outputs only the recovery password.

.PARAMETER KeyOnly
   If specified, outputs only the recovery password.

.NOTES
   Version: 1.0 4/14/2021 Silversword
   Version: 1.1 3/27/2023 styx-tdo and silversword. Adding comments and -KeyOnly for collector capabilities
#>

param(
    [switch]$KeyOnly = $false
)

if ($KeyOnly) {
    (Get-BitLockerVolume -MountPoint C).KeyProtector.RecoveryPassword
}
else {
    manage-bde -protectors C: -get
}
