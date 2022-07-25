<#
    .SYNOPSIS
        Lets you enable/disable screensaver and set options

    .DESCRIPTION
        You can enable and disable the screensaver, Set Timeout, Require password on wake, and change default screensaver

    .PARAMETER Active
        1 = Enable screensaver
        0 = Disable screensaver

    .PARAMETER Timeout
        Number in Minutes

    .PARAMETER IsSecure
        1 = Requires password after screensaver activates
        0 = Disabled password requirement

    .PARAMETER ScreensaverName
        Can optionally use any of these default windows screensavers: scrnsave.scr (blank), ssText3d.scr, Ribbons.scr, Mystify.scr, Bubbles.scr

    .EXAMPLE
        -Active 1 -Timeout 60 -IsSecure 0 -Name Bubbles.scr

    .EXAMPLE
        -Active 0
        
    .NOTES
        Change Log
        V1.0 Initial release
#>

param (
    [string] $Active,
    [string] $Timeout,
    [string] $IsSecure,
    [string] $ScreensaverName
)

# Write-Output "Args: $($args[0])"
Write-Output "Active: $Active"
Write-Output "Timeout: $Timeout"
Write-Output "IsSecure: $IsSecure"
Write-Output "ScreensaverName: $ScreensaverName"

IF (!$Active) {
    "Active is empty: $Active"
}
else {
    "Active is not empty: $Active"
}

'####'

IF ([string]::IsNullOrWhitespace($ScreensaverName)) {
    "Screensaver is empty: $ScreensaverName"
}
else {
    "Screensaver is not empty: $ScreensaverName"
}

'####'

IF (!$Active -and !$ScreensaverName) {
    "Both are empty: $Active"
}
else {
    "Both are not empty: $Active"
}



if (!$Active -And !$Timeout -And !$IsSecure -And !$ScreensaverName) {
    Write-Output "No arguments specified. Please provide at least one."
    Exit 1
}
else {
    Write-Output "There were args"
}

'####'

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

# Enable screensaver
$userRegistryPath = "Registry::HKEY_USERS\$($currentUserSID)\Control Panel\Desktop"


If (!$Active) {
    Set-ItemProperty -Path $userRegistryPath -Name "ScreenSaveActive" -Value $Active
    Write-Output "Set Active to: $Active"
}
else {
    Write-Output "Active was empty"
}


# Screensaver Timeout Value
If (!$Timeout) {
    Set-ItemProperty -Path $userRegistryPath -Name "ScreenSaveTimeOut" -Value $Timeout
    Write-Output "Set Timeout to: $Timeout"
}
else {
    Write-Output "Timeout was empty"
}


# On resume, display logon screen. 
If ($IsSecure -ne $null) {
    Set-ItemProperty -Path $userRegistryPath -Name "ScreenSaveIsSecure" -Value $IsSecure
    Write-Output "Set IsSecure to: $IsSecure"
}


# Set Screensaver to blank if not specified
if (!$ScreensaverName) {
    Set-ItemProperty -Path $userRegistryPath -Name scrnsave.exe -Value "c:\windows\system32\scrnsave.scr"
    Exit 0
}
else {
    Set-ItemProperty -Path $userRegistryPath -Name scrnsave.exe -Value "c:\windows\system32\$ScreensaverName"
    Exit 0
}
<#
    .SYNOPSIS
        Lets you enable/disable screensaver and set options

    .DESCRIPTION
        You can enable and disable the screensaver, Set Timeout, Require password on wake, and change default screensaver

    .PARAMETER Active
        1 = Enable screensaver
        0 = Disable screensaver

    .PARAMETER Timeout
        Number in Minutes

    .PARAMETER IsSecure
        1 = Requires password after screensaver activates
        0 = Disabled password requirement

    .PARAMETER ScreensaverName
        Can optionally use any of these default windows screensavers: scrnsave.scr (blank), ssText3d.scr, Ribbons.scr, Mystify.scr, Bubbles.scr

    .EXAMPLE
        Active 1 Timeout 60 IsSecure 0 Name Bubbles.scr

    .EXAMPLE
        Active 0
        
    .NOTES
        Change Log
        V1.0 Initial release
#>

param (
    [string] $Active,
    [string] $Timeout,
    [string] $IsSecure,
    [string] $ScreensaverName
)


# Enable screensaver
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveActive -Value $Active

# Screensaver Timeout Value
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveTimeOut -Value $Timeout

# On resume, display logon screen. 
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveIsSecure -Value $IsSecure

# Set Screensaver to blank if not specified
if (!$ScreensaverName) {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name scrnsave.exe -Value "c:\windows\system32\scrnsave.scr"
    Exit 0
}
else {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name scrnsave.exe -Value "c:\windows\system32\$ScreensaverName"
    Exit 0
}


