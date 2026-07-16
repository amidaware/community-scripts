<#
      .SYNOPSIS
      This will install software using the winget which should be on any up to date Windows PC
      .DESCRIPTION
      For installing packages using winget.
      .PARAMETER Mode
      4 options: install, uninstall,, update, show, search or upgrade.
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
    [string] $PackageName = "",
    [string] $Mode = "install"
)

$ErrorCount = 0

if ([string]::IsNullOrWhiteSpace($Mode)) {
    $Mode = "install"
}

$Mode = $Mode.ToLower()

$ValidModes = @("install", "uninstall", "search", "update", "show", "upgrade")

if ($Mode -notin $ValidModes) {
    Write-Output "Invalid mode: $Mode"
    Exit 1
}

$wingetloc = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Include winget.exe -Recurse -ErrorAction SilentlyContinue |
    Select-Object -Last 1 |
    ForEach-Object { $_.FullName } |
    Split-Path

if ([string]::IsNullOrWhiteSpace($wingetloc)) {
    Write-Output "winget.exe not found."
    Exit 1
}

$winget = Join-Path $wingetloc "winget.exe"

if (!(Test-Path $winget)) {
    Write-Output "winget.exe not found at $winget"
    Exit 1
}

if ($Mode -notin @("show", "upgrade") -and [string]::IsNullOrWhiteSpace($PackageName)) {
    Write-Output "No package name provided. Example: -PackageName Google.Chrome"
    Exit 1
}

switch ($Mode) {
    "show" {
        & $winget upgrade --accept-source-agreements
        Exit $LASTEXITCODE
    }

    "upgrade" {
        & $winget upgrade --all --accept-source-agreements --accept-package-agreements
        Exit $LASTEXITCODE
    }

    "update" {
        & $winget upgrade --id $PackageName --accept-source-agreements --accept-package-agreements
        Exit $LASTEXITCODE
    }

    "search" {
        & $winget search $PackageName --accept-source-agreements
        Exit $LASTEXITCODE
    }

    "install" {
        & $winget install --id $PackageName --accept-source-agreements --accept-package-agreements
        Exit $LASTEXITCODE
    }

    "uninstall" {
        & $winget uninstall --id $PackageName --accept-source-agreements
        Exit $LASTEXITCODE
    }
}
