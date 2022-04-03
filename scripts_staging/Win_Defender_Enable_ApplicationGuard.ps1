# Should be part of the full Defender Enable script as a parameter, once fully tested.
# Script to Install Windows Defender Application Guard.
# Created by TechCentre with the help and assistance of the internet.
# Restart Required to complete install.
#
# Sets Variable for feature to be installed.

<#
      .SYNOPSIS
      Script to Install Windows Defender Application Guard Feature. 
      .PARAMETER Mode
      The Enable is assumed, to disable feature use -mode disable
      .EXAMPLE
      -FeatureName NameofFeature -mode disable
      .EXAMPLE
      -FeatureName NameofFeature
  #>

param (
    [string] $Mode
)
$FeatureName = "Windows-Defender-ApplicationGuard"  

if ($Mode -eq "disable") {
    Write-Output "Disabling $FeatureName"
    Disable-WindowsOptionalFeature -online -FeatureName $FeatureName -NoRestart
}

else {
    # If Feature Installed already then skips otherwise installs.
    if ((Get-WindowsOptionalFeature -FeatureName $FeatureName -Online).State -eq "Enabled") {

        write-output "Windows Defender Application Guard Installed"

    }
    else {

        write-output "Windows Defender Application Guard Not Installed"

        Enable-WindowsOptionalFeature -online -FeatureName $FeatureName -NoRestart

    }
}
