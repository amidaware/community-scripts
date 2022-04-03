<#
      .SYNOPSIS
      Script to Install Windows Optional Features. 
      .PARAMETER Mode
      The Enable is assumed, to disable feature use -mode disable
      .PARAMETER FeatureName
      Set Feature to install by using -FeatureName NameofFeature
      .EXAMPLE
      -FeatureName NameofFeature -mode disable
      .EXAMPLE
      -FeatureName NameofFeature
  #>

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
