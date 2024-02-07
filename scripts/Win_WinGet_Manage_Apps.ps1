<#
      .SYNOPSIS
      This will install software using the winget which should be on any up to date Windows PC
      .DESCRIPTION
      For installing packages using winget.
      .PARAMETER Mode
      6 options: install, uninstall, search, update, show or upgrade.
      .PARAMETER PackageName
      Use this to specify which software to install eg: PackageName google.chrome
      .EXAMPLE
      -PackageName googlechrome
      .EXAMPLE
      -Mode upgrade
      .EXAMPLE
      -Mode uninstall -PackageName google.chrome
      .EXAMPLE
      -Mode update -PackageName google.chrome
      .EXAMPLE (to show updates available)
      -Mode show
      .NOTES
      9/2021 v1 Initial release by @silversword411 and @bradhawkins 
      11/14/2021 v1.1 Fixing typos and logic flow
	  18/08/2022 edited script to work with winget
  #>

param (
    [string] $PackageName,
    [string] $Mode = "install"
)

$wingetloc=(Get-Childitem -Path "C:\Program Files\WindowsApps" -Include winget.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Last 1 | %{$_.FullName} | Split-Path)
cd $wingetloc

$ErrorCount = 0

if ($Mode -eq "show") {
    .\winget.exe upgrade --accept-source-agreements
    Exit 0
}

if ($Mode -ne "update" -and !$PackageName) {
    write-output "No package name provided, please include Example: `"-PackageName google.chrome`" `n"
    Exit 1
}

if ($Mode -eq "upgrade") {
    .\winget.exe upgrade --all --accept-source-agreements
    Exit 0
}

if ($Mode -eq "update") {
    .\winget.exe upgrade $PackageName --accept-source-agreements
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
