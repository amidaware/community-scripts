<#

.SYNOPSIS
   For Setting up and running a LAPS (Local Administrator Password Solution)

.DESCRIPTION
   Long description
   eg Checks IP address on all local network adapters, and returns results

.EXAMPLE
   Example of how to use this cmdlet

.PARAMETER LAPSID
   If you want a custom Local Username, create a TRMM Global Key called: LAPS_username otherwise LocalAdmin will be used: 
   -LAPSID {{global.LAPS_username}}

.PARAMETER PassLength
   If you want a password with a different length use: 
   -PassLength 20

.PARAMETER HideUser
    If you want to hide the login username from login screen use:
    -HideUser

.OUTPUTS
   The current LAPS admin password. Use as a collector script to write it to a custom_field

.NOTES
   v1.0 subz original, tweaked from Cyberdrain blog
   v2.0 silversword adding TRMM parameters, documenting etc
#>

# LAPS script from @subz
# TODO: Needs comments, and parameters for New Admin. Merge/consolidate with other admin Local Administrator Password Scripts if possible
# Add hiding login ID https://www.windowscentral.com/how-hide-specific-user-accounts-sign-screen-windows-10

param(
    [string]$LAPSID,
    [Int]$PassLength,
    [Switch]$HideUser = $false
)

# Hide errors when noone is logged in
#$ErrorActionPreference= 'silentlycontinue'

$ComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object name).name

#####################################################################


if (!($LAPSID)) {
    Write-Output "No LAPSID defined. Using LocalAdmin"
    $LAPSID = "LocalAdmin"
}

if (!($PassLength)) {
    Write-Output "No PassLength defined. Using 16"
    $PassLength = "16"
}

#####################################################################

Write-Output "LAPSID is: $LAPSID"

add-type -AssemblyName System.Web
$LocalAdminPassword = [System.Web.Security.Membership]::GeneratePassword($PassLength, 2)

$checkuser = Get-LocalUser | where-Object Name -eq $LAPSID | Measure
if ($checkuser.Count -eq 0) {
    Write-Output "User $($LAPSID) was not found. Creating User and adding to Admin group"
    New-LocalUser -Name $LAPSID -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
    Add-LocalGroupMember -Group Administrators -Member $LAPSID

    if ($HideUser) {
        Write-Output "HideUser enabled. Writing reg key" 
        if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList") -ne $true) {  
            New-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -force -ea SilentlyContinue 
        };
        New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList' -Name $LAPSID -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
    }
    else {
        Write-Output "No HideUser, Skipping"
    }
}
else {
    Write-Output "User $($LAPSID) was found. Setting password for existing user."
    Set-LocalUser -Name $LAPSID -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force)
}



#Write-Output "The $LAPSID account has been enabled on $($ComputerName) and a new password has been set"

Write-Output "$($ComputerName)\$LAPSID"
Write-Output "$($LocalAdminPassword)"