# https://adamtheautomator.com/powershell-get-current-user/

#There are errors if no user is logged in, hide errors
$ErrorActionPreference = 'silentlycontinue'

$currentuser = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]

# (Get-CimInstance -ClassName Win32_ComputerSystem).Username                    # ComputerName\LoggedInUsername
#((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]       # LoggedInUsername

$Domain = (Get-WmiObject Win32_ComputerSystem | Select-Object Username).Username.Split("\\")[0]             # Get Domain
$UserName = (Get-WmiObject Win32_ComputerSystem | Select-Object Username).Username.Split("\\")[1]           # Get Logged In Username
$SID = (New-Object System.Security.Principal.NTAccount($Domain, $UserName)).Translate([System.Security.Principal.SecurityIdentifier]).Value     # Get Logged In Users SID


If (!$currentuser) {    
    Write-Output "Noone currently logged in"
}
else {
    Write-Output "Currently logged in user is: $currentuser"
}

$LoggedOnUser = (Get-WmiObject -Class Win32_Process -Filter 'Name="explorer.exe"').GetOwner().User | select-object -first 1
Write-Output "Alt method: Currently logged in user is: $LoggedOnUser"

################### REGISTRY AS HKCU #######################

# https://github.com/imabdk/PowerShell/blob/master/Edit-HKCURegistryfromSystem.ps1

<#
.SYNOPSIS
    Modify registry for the CURRENT user coming from SYSTEM context
 
.DESCRIPTION
    Same as above

.NOTES
    Filename: Edit-HKCURegistryFromSystem.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/back-to-basics-modifying-registry-for-the-current-user-coming-from-system-context    
#> 
function Get-CurrentUser() {
    try { 
        $currentUser = (Get-Process -IncludeUserName -Name explorer | Select-Object -First 1 | Select-Object -ExpandProperty UserName).Split("\")[1] 
    } 
    catch { 
        Write-Output "Failed to get current user." 
    }
    if (-NOT[string]::IsNullOrEmpty($currentUser)) {
        Write-Output $currentUser
    }
}
function Get-UserSID([string]$fCurrentUser) {
    try {
        $user = New-Object System.Security.Principal.NTAccount($fcurrentUser) 
        $sid = $user.Translate([System.Security.Principal.SecurityIdentifier]) 
    }
    catch { 
        Write-Output "Failed to get current user SID."   
    }
    if (-NOT[string]::IsNullOrEmpty($sid)) {
        Write-Output $sid.Value
    }
}
$currentUser = Get-CurrentUser
$currentUserSID = Get-UserSID $currentUser
$userRegistryPath = "Registry::HKEY_USERS\$($currentUserSID)\SOFTWARE\Policies\Microsoft\office\16.0\outlook\cached mode"
New-ItemProperty -Path $userRegistryPath -Name "Enabled" -Value 0 -PropertyType DWORD -Force | Out-Null