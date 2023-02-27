<#
      .SYNOPSIS
      This will disable or enable Windows Hello on a Windows PC
      .DESCRIPTION
      For enabling or disabling Windows Hello, if no parameters are set it will disable Windows Hello
      .PARAMETER Mode
      2 options: enable and disable
      .EXAMPLE
      -Mode enable
      .NOTES
      2/2023 v1 Initial release by @dinger1986
  #>

param (
    [string] $Mode
)

#$ErrorActionPreference= 'silentlycontinue'

$ComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object name).name

#####################################################################

if (!($Mode)) {
    Write-Output "No Mode defined. Using disable"
    $Mode = "disable"
}

#####################################################################


if ($Mode -eq "enable") {
    Write-Output "Mode enable. Writing reg keys"
    if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork\Enabled") -ne $true) {  
        Write-Output "Creating Enabled Key"
        New-Item "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -force -ea SilentlyContinue 
    };
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork' -Name Enabled -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork' -Name DisablePostLogonProvisioning -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
}
else {
    Write-Output "Mode disable. Writing reg keys"
    if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork\Enabled") -ne $true) {  
        Write-Output "Creating Disabled Keys"
        New-Item "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -force -ea SilentlyContinue 
    };
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork' -Name Enabled -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork' -Name DisablePostLogonProvisioning -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
}

Write-Output "Done"
