<#
      .SYNOPSIS
      This will install software using winget which should be on any up to date Windows PC
      .DESCRIPTION
      For installing packages using winget.
      .PARAMETER Mode
      5 options: install, uninstall, search, show, or upgrade.
      .PARAMETER PackageName
      Use this to specify which software to install eg: PackageName google.chrome
      .EXAMPLE
      -PackageName google.chrome
      .EXAMPLE
      -Mode upgrade                           # Upgrades all packages
      .EXAMPLE
      -Mode upgrade -PackageName google.chrome # Upgrades only specified package
      .EXAMPLE
      -Mode uninstall -PackageName google.chrome
      .EXAMPLE (to show package information)
      -Mode show -PackageName google.chrome
      .NOTES
      9/2021 v1 Initial release by @silversword411 and @bradhawkins 
      11/14/2021 v1.1 Fixing typos and logic flow
      18/08/2022 edited script to work with winget
      03/12/2025 Modified to remove update, fix upgrade behavior, and fix show mode to use correct command by @jd on Discord
  #>

param (
    [string] $PackageName,
    [string] $Mode = "install"
)

$wingetloc = (Get-Childitem -Path "C:\Program Files\WindowsApps" -Include winget.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Last 1 | %{$_.FullName} | Split-Path)
cd $wingetloc

$ErrorCount = 0

# Require PackageName for all modes except upgrade
if ($Mode -ne "upgrade" -and !$PackageName) {
    write-output "No package name provided, please include Example: `"-PackageName google.chrome`" `n"
    Exit 1
}

if ($Mode -eq "show") {
    .\winget.exe show $PackageName --accept-source-agreements
    Exit 0
}

if ($Mode -eq "upgrade") {
    if ($PackageName) {
        # Upgrade specific package if PackageName is provided
        .\winget.exe upgrade $PackageName --accept-source-agreements
    } else {
        # Upgrade all packages if no PackageName is provided
        .\winget.exe upgrade --all --accept-source-agreements
    }
    Exit 0
}

if ($Mode -eq "search") {
    .\winget.exe search $PackageName --accept-source-agreements
    Exit 0
}

if ($Mode -eq "install") {
    .\winget.exe install $PackageName --accept-source-agreements --accept-package-agreements
    Exit 0
}

if ($Mode -eq "uninstall") {
    .\winget.exe uninstall $PackageName --accept-source-agreements
    Exit 0
}
