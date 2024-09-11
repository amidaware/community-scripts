<#
    .SYNOPSIS
    Installs, uninstalls, upgrades, or lists software with rate limiting when run with Hosts parameter

    .DESCRIPTION
    This script uses Chocolatey to manage software packages. It introduces rate limiting when run on multiple hosts to avoid hitting rate limits at chocolatey.org. Use the Hosts parameter to specify the number of computers the script is running on.

    .PARAMETER Mode
    5 modes: 'install' (default), 'uninstall', 'upgrade', 'upgrade-only-installed' or 'list'.
    Mode 'install' installs the software specified by "PackageName"
    Mode 'uninstall' removes the software specified by "PackageName"
    Mode 'upgrade' checks for newer version and upgrades the package(s). If package is not existing on system it gets installed (default behaviour of chocolatey). If no PackageName is given all installed packages are being updated.
    Mode 'upgrade-only-installed' checks for newer version of the package(s) and upgrades it. It will _not_ install new software (by adding --failonnotinstalled to the choco-command).
    Mode 'list' lists packages which are installed by chocolatey on the target
    Mode 'list-upgradeable' lists packages which are installed by chocolatey on the target but have updates available
    
    .PARAMETER Hosts
    Use this to specify the number of computer(s) you're running the command on. This will dynamically introduce waits to try and minimize the chance of hitting rate limits (20/min) on the chocolatey.org site: Hosts 20

    .PARAMETER PackageName
    Use this to specify which software('s) to install eg: PackageName googlechrome. You can use multiple values using comma separated.

    .EXAMPLE
    -Hosts 20 -PackageName googlechrome

    .EXAMPLE
    -Mode upgrade -Hosts 50 -PackageName chocolatey

    .EXAMPLE
    -Mode upgrade-only-installed -Hosts 20 -PackageName googlechrome,firefox

    .EXAMPLE
    -Mode list

    .NOTES
    9/2021 v1 Initial release by @silversword411 and @bradhawkins 
    11/14/2021 v1.1 Fixing typos and logic flow
    12/8/2023 v1.3 Adding list, making choco full path
    2/22/2024 v1.4 Adding 'upgrade-only-installed' as mode by @derfladi
    3/5/2024 v1.5 silversword411 Adding --no-progress to minimize output
    5/21/2024 v1.6 silversword411 Adding list-upgradeable
#>

param (
    [Parameter(Mandatory = $false)]
    [int] $Hosts = 0,

    [Parameter(Mandatory = $false)]
    [string[]] $PackageName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("install", "uninstall", "upgrade", "upgrade-only-installed", "list", "list-upgradeable")]
    [string] $Mode = "install"
)

$chocoExePath = "$env:PROGRAMDATA\chocolatey\choco.exe"

if (-not (Test-Path $chocoExePath)) {
    Write-Host "Chocolatey is not installed."
    Exit 1
}

$ErrorCount = 0

if ($Mode -ne "upgrade" -and $Mode -ne "upgrade-only-installed" -and $Mode -ne "list" -and $Mode -ne "list-upgradeable" -and -not $PackageName) {
    Write-Host "Error: No package name provided. Please specify a package name, e.g., `-PackageName googlechrome`."
    Exit 1
}

# Calculate random delay based on the number of hosts
$randDelay = if ($Hosts -gt 0) { Get-Random -Minimum 1 -Maximum (($Hosts + 1) * 6) } else { 1 }

Write-Host "Sleeping $randDelay seconds"
Start-Sleep -Seconds $randDelay

switch ($Mode) {
    "install" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath install $package -y --no-progress
                if ($LASTEXITCODE -ne 0) { $ErrorCount++ }
            }
        }
    }
    "uninstall" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath uninstall $package -y
                if ($LASTEXITCODE -ne 0) { $ErrorCount++ }
            }
        }
    }
    "upgrade" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath upgrade $package -y --no-progress
                if ($LASTEXITCODE -ne 0) { $ErrorCount++ }
            }
        }
        else {
            & $chocoExePath upgrade all -y --no-progress
        }
    }
    "upgrade-only-installed" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath upgrade $package --failonnotinstalled -y
                if ($LASTEXITCODE -ne 0) { $ErrorCount++ }
            }
        }
        else {
            & $chocoExePath upgrade all --failonnotinstalled -y
        }
    }
    "list" {
        & $chocoExePath list
    }
    "list-upgradeable" {
        & $chocoExePath outdated
    }
}

if ($ErrorCount -gt 0) {
    Write-Host "$ErrorCount errors occurred during the operation."
}

Exit 0
