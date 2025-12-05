<#
.SYNOPSIS
    Checks for outdated Chocolatey packages and lists them.

.DESCRIPTION
    This script verifies that Chocolatey is installed on the system. 
    If installed, it retrieves and displays a list of packages that have available updates.
    If no packages are outdated, it confirms that all packages are up to date.
    If Chocolatey is not installed or an error occurs, it exits with an error message.


.NOTES
    Author: SAN
    Date: 01.01.2024
    #public

.CHANGELOG
    19.10.25 SAN Code cleanup and add output if up-to-date

#>

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Please install Chocolatey to use this script."
    exit 1
}

# Get a list of upgradable packages
$upgradablePackages = choco outdated 2>$null

# Check the output and display results
if ($upgradablePackages -match "Chocolatey has determined 0 package") {
    Write-Host "All up-to-date"
    exit 0
}
elseif ($upgradablePackages) {
    Write-Host "Upgradable packages:`n"
    $upgradablePackages -split "`r?`n" | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -and ($_ -notmatch "Chocolatey has determined")) {
            Write-Host $_
        }
    }
    exit 0
}
else {
    Write-Host "Error: Unable to determine upgradable packages."
    exit 1
}
