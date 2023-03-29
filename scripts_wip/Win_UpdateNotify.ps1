<#
.SYNOPSIS
    Checks for patches, updates, notifies with the option to delay.
.DESCRIPTION
    Placeholder text
.INSTRUCTIONS
    Placeholder text
.NOTES
    Version: 1.0
    Author: redanthrax

    some of this was shamelessly stolen from Win_Toast_Reboot_Request
#>

Param(
    [switch]$IncludeDrivers = $false,
    
    [Parameter(Mandatory)]
    [string]$HeroImage,

    [Parameter(Mandatory)]
    [string]$Name,

    [switch]$ForceTargetReset
)

function Win_UpdateNotify {
    [CmdletBinding()]
    Param(
        [switch]$IncludeDrivers,
        
        [Parameter(Mandatory)]
        [string]$HeroImage,

        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$ForceTargetReset
    )

    Begin {
        #Ensure Requirements
        Install-PackageProvider NuGet -Force | Out-Null
        Set-PSRepository PSGallery -InstallationPolicy Trusted | Out-Null
        if (-Not(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Install-Module PSWindowsUpdate -Repository PSGallery
        }
        if (-Not(Get-Module -ListAvailable -Name PendingReboot)) {
            Install-Module PendingReboot -Repository PSGallery
        }
        if (-Not(Get-Module -ListAvailable -Name BurntToast)) {
            Install-Module BurntToast -Repository PSGallery
        }
        if (-Not(Get-Module -ListAvailable -Name RunAsUser)) {
            Install-Module RunAsUser -Repository PSGallery
        }

        $hkcr = @{
            Name = "HKCR"
            PSProvider = "Registry"
            Root = "HKEY_CLASSES_ROOT"
            ErrorAction = "SilentlyContinue"
        }

        New-PSDrive @hkcr | out-null
        $ProtocolHandler = get-item 'HKCR:\ToastReboot' -erroraction 'silentlycontinue'
        if (!$ProtocolHandler) {
            #create handler for reboot
            New-Item 'HKCR:\ToastReboot' -force
            Set-ItemProperty 'HKCR:\ToastReboot' -name '(DEFAULT)' -value 'url:ToastReboot' -force
            Set-ItemProperty 'HKCR:\ToastReboot' -name 'URL Protocol' -value '' -force
            New-ItemProperty -path 'HKCR:\ToastReboot' -propertytype dword -name 'EditFlags' -value 2162688
            New-Item 'HKCR:\ToastReboot\Shell\Open\command' -force
            Set-ItemProperty 'HKCR:\ToastReboot\Shell\Open\command' -name '(DEFAULT)' -value 'C:\Windows\System32\shutdown.exe /r /t 1' -force
        }

        Set-ItemProperty 'HKCR:\ToastReboot' -name 'HeroImage' -value $HeroImage | Out-Null
        Set-ItemProperty 'HKCR:\ToastReboot' -name 'Name' -value $Name | Out-Null

        if ($ForceTargetReset) {
            RemoveRegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'TargetReleaseVersion'
            RemoveRegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'TargetReleaseVersionInfo'
            RemoveRegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ProductVersion'
        }
    }

    Process {
        Try {
            #check if reboot pending first
            if ((Test-PendingReboot -SkipConfigurationManagerClientCheck).IsRebootPending) {
                #Notify the user
                Write-Output "Reboot is pending, notifying user."
                Invoke-AsCurrentUser -ScriptBlock {
                    $hkcr = @{
                        Name = "HKCR"
                        PSProvider = "Registry"
                        Root = "HKEY_CLASSES_ROOT"
                        ErrorAction = "SilentlyContinue"
                    }
                    New-PSDrive @hkcr | out-null
                    $HeroImage = Get-ItemPropertyValue -Path 'HKCR:\ToastReboot' -Name HeroImage
                    $Name = Get-ItemPropertyValue -Path 'HKCR:\ToastReboot' -Name Name
                    $heroimage = New-BTImage -Source $HeroImage -HeroImage
                    $Text1 = New-BTText -Content $Name
                    $Text2 = New-BTText -Content "Updates were installed and a reboot is needed. Please select if you'd like to reboot now, or snooze this message for later."
                    $Button = New-BTButton -Dismiss -Content "Wait"
                    $Button2 = New-BTButton -Content "Reboot Now" -Arguments "ToastReboot:" -ActivationType Protocol
                    $action = New-BTAction -Buttons $Button, $Button2
                    $Binding = New-BTBinding -Children $text1, $text2 -HeroImage $heroimage
                    $Visual = New-BTVisual -BindingGeneric $Binding
                    $Content = New-BTContent -Visual $Visual -Actions $action
                    Submit-BTNotification -Content $Content
                } | Out-Null
            }
            else {
                #no reboots pending, get and install updates
                $getParams = @{}
                if (-Not($IncludeDrivers)) {
                    $getParams.Add("UpdateType", "Software")
                }

                $updates = Get-WindowsUpdate @getParams
                if ($updates.Count -gt 0) {
                    Write-Output "Installing the following updates."
                    foreach ($update in $updates) {
                        $update.Title
                    }

                    $updateParams = @{
                        Install = $true
                        AcceptAll = $true
                        IgnoreReboot = $true
                        Silent = $true
                    }

                    if(-Not($IncludeDrivers)) {
                        $updateParams.Add("UpdateType", "Software")
                    }

                    #Do the updates
                    Get-WindowsUpdate @updateParams
                }
                else {
                    Write-Output "There are no pending updates."
                }
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

Function RemoveRegistryValue($path, $name) {
    if (Get-ItemProperty -Path $path -Name $name -ErrorAction Ignore) {
        Write-Output "Removing $name registry value"
        Remove-ItemProperty -Path $path -Name $name -Force
    }
}

if (-not(Get-Command 'Win_UpdateNotify' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    IncludeDrivers = $IncludeDrivers
    HeroImage = $HeroImage
    Name = $Name
    ForceTargetReset = $ForceTargetReset
}

Win_UpdateNotify @scriptArgs
