<#
.SYNOPSIS
    Installs or uninstalls Sysinternals and nirlauncher using Chocolatey. 

.DESCRIPTION
    This script installs or uninstalls the Sysinternals and nirlauncher packages via Chocolatey. .
    If the environment variable "uninstall" is set to "1", it will uninstall both packages instead of installing.

.EXAMPLE
    uninstall=1

.NOTES
    Author: SAN
    Date: 26.06.25
    #public

.CHANGELOG

#>


if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Error "Chocolatey is not installed or not in PATH."
    exit 1
}

$uninstall = $env:uninstall

if ($uninstall -eq "1") {
    Write-Host "Start uninstall"
    choco uninstall sysinternals -y
    choco uninstall nirlauncher -y
    choco uninstall powertoys -y
} else {
    Write-Host "Start install"
    choco install sysinternals -y --ignore-checksums --no-progress --force
    choco install nirlauncher -y --package-parameters="/Sysinternals" --no-progress --force
    choco install powertoys -y --no-progress --force

    Write-Host "Launcher available at C:\tools\NirLauncher"
}