#TODO merge enable, and current live bitlocker script together for a single commit

<#
.SYNOPSIS
    Enables Bitlocker

.DESCRIPTION
    Enables bitlocker, and shows recovery keys.	Assumes c, but you can specify a drive if you want.
    
.PARAMETER Drive
	Optional: Specify drive letter if you want to check a drive other than c

.OUTPUTS
    Results are printed to the console.

.NOTES
    Change Log
    V1.0 Initial release from dinger1986 https://discord.com/channels/736478043522072608/744281869499105290/836871708790882384
#>

param (
    [string] $Drive = "c"
)

If (!(test-path $env:programdata\TacticalRMM\scripts\)) {
    New-Item -ItemType Directory -Force -Path $env:programdata\TacticalRMM\scripts\
}

Enable-Bitlocker -MountPoint $Drive -UsedSpaceOnly -SkipHardwareTest -RecoveryPasswordProtector
manage-bde -protectors $Drive -get

$bitlockerkey = manage-bde -protectors $Drive -get
(
    Write-Output $bitlockerkey
)>"$env:programdata\TacticalRMM\scripts\bitlockerkey.txt"
