<#
    .SYNOPSIS
    Installs, uninstalls, upgrades, or lists software with rate limiting when run with Hosts parameter

    .DESCRIPTION
    This script uses Chocolatey to manage software packages. It introduces rate limiting when run on multiple hosts to avoid hitting rate limits at chocolatey.org. Use the Hosts parameter to specify the number of computers the script is running on.

    .PARAMETER Mode
    4 modes: 'install' (default), 'uninstall', 'upgrade', or 'list'.

    .PARAMETER Hosts
    Use this to specify the number of computer(s) you're running the command on. This will dynamically introduce waits to try and minimize the chance of hitting rate limits (20/min) on the chocolatey.org site: Hosts 20

    .PARAMETER PackageName
    Use this to specify which software('s) to install eg: PackageName googlechrome. You can use multiple values using comma separated.

    .EXAMPLE
    -Hosts 20 -PackageName googlechrome

    .EXAMPLE
    -Mode upgrade -Hosts 50 -PackageName chocolatey

    .EXAMPLE
    -Mode list

    .NOTES
    9/2021 v1 Initial release by @silversword411 and @bradhawkins 
    11/14/2021 v1.1 Fixing typos and logic flow
    12/8/2023 v1.3 Adding list, making choco full path
#>

param (
    [Parameter(Mandatory = $false)]
    [int] $Hosts = 0,

    [Parameter(Mandatory = $false)]
    [string[]] $PackageName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("install", "uninstall", "upgrade", "list")]
    [string] $Mode = "install"
)

$chocoExePath = "$env:PROGRAMDATA\chocolatey\choco.exe"

if (-not (Test-Path $chocoExePath)) {
    Write-Output "Chocolatey is not installed."
    Exit 1
}

$ErrorCount = 0

if ($Mode -ne "upgrade" -and $Mode -ne "list" -and -not $PackageName) {
    Write-Output "Error: No package name provided. Please specify a package name, e.g., `-PackageName googlechrome`."
    Exit 1
}

# Calculate random delay based on the number of hosts
$randDelay = if ($Hosts -gt 0) { Get-Random -Minimum 1 -Maximum (($Hosts + 1) * 6) } else { 1 }

Write-Output "Sleeping $randDelay seconds"
Start-Sleep -Seconds $randDelay

switch ($Mode) {
    "install" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath install $package -y
            }
        }
    }
    "uninstall" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath uninstall $package -y
            }
        }
    }
    "upgrade" {
        if ($PackageName) {
            foreach ($package in $PackageName) {
                & $chocoExePath upgrade $package -y
            }
        }
        else {
            & $chocoExePath upgrade all -y
        }
    }
    "list" {
        & $chocoExePath list
    }
}

Exit 0
