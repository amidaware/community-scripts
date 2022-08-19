<#
      .SYNOPSIS
      This will install software using the winget which should be on any up to date Windows PC
      .DESCRIPTION
      For installing packages using winget. If running on more than 30 agents at a time make sure you also change the script timeout setting.
      .PARAMETER Mode
      4 options: install, uninstall, search or upgrade.
      .PARAMETER PackageName
      Use this to specify which software to install eg: PackageName google.chrome
      .EXAMPLE
      -PackageName googlechrome
      .EXAMPLE
      -Mode upgrade
      .EXAMPLE
      -Mode uninstall -PackageName google.chrome
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

if ($Mode -ne "upgrade" -and !$PackageName) {
    write-output "No package name provided, please include Example: `"-PackageName google.chrome`" `n"
    Exit 1
}

if ($Mode -eq "upgrade") {
    .\winget.exe upgrade --all --accept-source-agreements
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
