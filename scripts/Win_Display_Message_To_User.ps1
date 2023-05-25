<#
.SYNOPSIS
    Displays a popup message to the currently logged on user.

.DESCRIPTION
    This script uses the RunAsUser and BurntToast modules to display a popup message to the currently logged on user. 

.PARAMETER
    The message text is the arguments can be provided as arguments or quoted with 'your message here' if special characters are used.

.EXAMPLE
    Example usage:
    Hello, this is a test message!

.EXAMPLE
    Another example usage with special characters:
    'Hello, "this" is a test message!'

.NOTES
    C:\Program Files\TacticalAgent\BurntToastLogo.png will be displayed if the file exists. Image dimensions 478px (W) x 236px (H)
    BurntToast Module Source and Examples: https://github.com/Windos/BurntToast
    RunAsUser Module Source and Examples: https://github.com/KelvinTegelaar/RunAsUser
    v1.0 2/10/2021 bradhawkins85 Initial release
    v1.1 5/23/2023 silversword411 
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#$ErrorActionPreference = 'silentlycontinue'

Function InstallRequirements {
    # Check if NuGet is installed
    if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
        Write-Output "Nuget installing"
        Install-PackageProvider -Name NuGet -Force
    }
    else {
        Write-Output "Nuget already installed"
    }
    if (-not (Get-Module -Name BurntToast -ListAvailable)) {
        Write-Output "BurntToast installing"
        Install-Module -Name BurntToast -Force
    }
    else {
        Write-Output "BurntToast already installed"
    }

    if (-not (Get-Module -Name RunAsUser -ListAvailable)) {
        Write-Output "RunAsUser installing"
        Install-Module -Name RunAsUser -Force
    }
    else {
        Write-Output "RunAsUser already installed"
    }
}
InstallRequirements

Function TRMMTempFolder {
    # Make sure the temp folder exists
    If (!(test-path $env:ProgramData\TacticalRMM\temp)) {
        New-Item -ItemType Directory -Force -Path "$env:ProgramData\TacticalRMM\temp"
    }
    Else {
        Write-Output "TRMM Temp folder exists"
    }
}
TRMMTempFolder

# Used to store text to show user and use inside the script block.
Set-Content -Path $env:ProgramData\TacticalRMM\temp\toastmessage.txt -Value $args

Invoke-AsCurrentUser -scriptblock {
 
    $messagetext = Get-Content -Path $env:ProgramData\TacticalRMM\temp\toastmessage.txt
    $heroimage = New-BTImage -Source 'C:\Program Files\TacticalAgent\BurntToastLogo.png' -HeroImage
    $Text1 = New-BTText -Content  "Message from IT"
    $Text2 = New-BTText -Content "$messagetext"
    $Button = New-BTButton -Content "Snooze" -snooze -id 'SnoozeTime'
    $Button2 = New-BTButton -Content "Dismiss" -dismiss
    $5Min = New-BTSelectionBoxItem -Id 5 -Content '5 minutes'
    $10Min = New-BTSelectionBoxItem -Id 10 -Content '10 minutes'
    $1Hour = New-BTSelectionBoxItem -Id 60 -Content '1 hour'
    $4Hour = New-BTSelectionBoxItem -Id 240 -Content '4 hours'
    $1Day = New-BTSelectionBoxItem -Id 1440 -Content '1 day'
    $Items = $5Min, $10Min, $1Hour, $4Hour, $1Day
    $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 10 -Items $Items
    $action = New-BTAction -Buttons $Button, $Button2 -inputs $SelectionBox
    $Binding = New-BTBinding -Children $Text1, $Text2 -HeroImage $heroimage
    $Visual = New-BTVisual -BindingGeneric $Binding
    $Content = New-BTContent -Visual $Visual -Actions $action
    Submit-BTNotification -Content $Content
}

# Cleanup temp file for message variables
Remove-Item -Path $env:ProgramData\TacticalRMM\temp\toastmessage.txt
