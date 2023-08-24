<#
.SYNOPSIS
    Script to hide the UI toggle switch in Outlook.
.DESCRIPTION
    This script adds a registry key to hide the UI toggle switch
    in Outlook. It checks if the specified registry key exists, creates
    it if not, and then sets a DWORD value to hide the toggle switch.

.PARAMETER DEBUG
    Add - Debug to see debugging information.

.NOTES
    Author         : ITDoneRightNC + SilverSword411
    Version        : 1.0
    Date           : 8/23/2023

#>

#Simple Logging

param (
    [switch]$debug
)

# For setting debug output level. -debug switch will set $debug to true
if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

If (!(test-path "c:\ProgramData\TacticalRMM\temp\")) {
    Write-Output "Creating c:\ProgramData\TacticalRMM\temp Folder"
    New-Item "c:\ProgramData\TacticalRMM\temp" -itemType Directory
}
#Install Run As User Requirements

Function InstallRunAsUserRequirements {
    # Install Requirements for RunAsUser
    if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
        Write-Debug "Nuget installing"
        Install-PackageProvider -Name NuGet -Force
    }
    else {
        Write-Debug "Nuget already installed"
    }
    if (-not (Get-Module -Name RunAsUser -ListAvailable)) {
        Write-Debug "RunAsUser installing"
        Install-Module -Name RunAsUser -Force
    }
    else {
        Write-Debug "RunAsUser already installed"
    }
}
# Put this inside an always false conditional so that the template can run without changing the environment.
InstallRunAsUserRequirements
Invoke-AsCurrentUser -scriptblock {

    IF (!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name $name -Value $value `
            -PropertyType DWORD -Force | Out-Null
    }
    ELSE {
        New-ItemProperty -Path $registryPath -Name $name -Value $value `
            -PropertyType DWORD -Force | Out-Null
    }
          
    # Expand Explorer Ribbon by default
    $registryPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
    $Name = "HideNewOutlookToggle"
    $value = "0"
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    #End Of Script
    Write-Output "Stop." | Out-File -append -FilePath c:\ProgramData\TacticalRMM\temp\raulog.txt
}
# Get userland return info for Tactical Script History
$exitdata = Get-Content -Path "c:\ProgramData\TacticalRMM\temp\raulog.txt"
Write-Output $exitdata
# Cleanup raulog.txt File
Remove-Item -path "c:\ProgramData\TacticalRMM\temp\raulog.txt"

