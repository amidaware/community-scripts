<#

.SYNOPSIS
   For Setting up and running a LAPS (Local Administrator Password Solution) for non-AD
   https://www.microsoft.com/en-us/download/details.aspx?id=46899

.DESCRIPTION
   This will create a local administrator, with each run it will change that localadmin user's password. This will let you make users non-administrators, but still have a local admin account.
   Walkthru here: https://docs.tacticalrmm.com/functions/examples/#setup-laps-local-administrator-password-solution

.PARAMETER LAPSID
   If you want a custom Local Username used server wide, create a TRMM Global Key called: LAPS_username otherwise LocalAdmin will be used:
   -LAPSID {{global.LAPS_username}}
   -LAPSID customadminname

.PARAMETER PassLength
   If you want a password with a length other than 16 use:
   -PassLength 20

.PARAMETER HideUser
    If you want to hide the login username from the windows login screen use:
    -HideUser

.PARAMETER ShowUser
    Show the username on the login screen:
    -ShowUser

.EXAMPLE
   -LAPSID {{global.LAPS_username}}

.EXAMPLE
   -LAPSID corpadmin

.EXAMPLE
   -LAPSID {{global.LAPS_username}} -HideUser

.EXAMPLE
   -LAPSID {{global.LAPS_username}} -ShowUser

.EXAMPLE
   -LAPSID {{global.LAPS_username}} -PassLength 20 -HideUser

.OUTPUTS
   The current LAPS admin password. Use as a collector script to write it to a custom_field

.NOTES
   v1.0 subz original, tweaked from Cyberdrain blog
   v2.0 silversword adding TRMM parameters, documenting etc
#>


param(
    [string]$LAPSID,
    [Int]$PassLength,
    [Switch]$HideUser = $false,
    [Switch]$ShowUser = $false
)


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

if ($ShowUser) {
    Write-Output "Showing User on Login page and exit"
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList' -Name $LAPSID -Value 1 -Force
    Exit 0
}


add-type -AssemblyName System.Web
$LocalAdminPassword = [System.Web.Security.Membership]::GeneratePassword($PassLength, 2)

$checkuser = Get-LocalUser | where-Object Name -eq $LAPSID | Measure-Object
if ($checkuser.Count -eq 0) {
    Write-Output "User $($LAPSID) was not found. Creating User and adding to Admin group"
    New-LocalUser -Name $LAPSID -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
    Add-LocalGroupMember -SID S-1-5-32-544 -Member $LAPSID
}
else {
    Write-Output "User $($LAPSID) was found. Setting password for existing user."
    Set-LocalUser -Name $LAPSID -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force)
}

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


#Write-Output "The $LAPSID account has been enabled on $($ComputerName) and a new password has been set"

Write-Output "$($ComputerName)\$LAPSID"
Write-Output "$($LocalAdminPassword)"
