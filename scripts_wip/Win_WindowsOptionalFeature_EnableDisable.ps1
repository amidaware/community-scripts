# Script to Install Windows Defender Application Guard.
# Created by TechCentre with the help and assistance of the internet.
# Restart Required to complete install.
# TODO Needs parameterization for enable/disable

param (
    [string] $FeatureName,
    [string] $Mode
)

# If Feature Installed already then skips otherwise installs.
if ((Get-WindowsOptionalFeature -FeatureName $FeatureName -Online).State -eq "Enabled") {

    write-host "Installed"

}
else {

    write-host "not Installed"

    Enable-WindowsOptionalFeature -online -FeatureName $FeatureName -NoRestart

}
if ($Mode -eq "disable") {
    Write-Output "Disabling $FeatureName"
    Disable-WindowsOptionalFeature -online -FeatureName $FeatureName -NoRestart
}

else {
    Write-Output "Enabling $FeatureName"
    Enable-WindowsOptionalFeature -online -FeatureName $FeatureName -NoRestart
}
