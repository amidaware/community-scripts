<#
.SYNOPSIS
    This script checks for available Windows updates and installs them using the PSWindowsUpdate module.

.DESCRIPTION
    This PowerShell script is designed to automate the process of checking for and installing Windows updates. 
    It first ensures that the PSWindowsUpdate module is installed and then proceeds to check for available updates. 
    If updates are found, it initiates the update process, installs all available updates, and reboots if necessary.
    Finally, it retrieves and displays the date of the last successful installation of Windows updates.

.NOTES
    Author: SAN
    Date: 02.04.24
    Dependency: PowerShell 7 snippet, PSWindowsUpdate module
    #public

.CHANGELOG

#>




{{CallPowerShell7}}

# Set TLS version to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Check if PSWindowsUpdate module is available
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Write-Output "PSWindowsUpdate is already installed"
} else {
    # If module is not available, install it
    Write-Output "Installing PSWindowsUpdate module..."
    Install-Module -Name PSWindowsUpdate -Force

    # Check if there was an error during installation and attempt to install NuGet package provider if necessary
    if ($?) {
        Write-Output "PSWindowsUpdate module installed successfully."
    } else {
        Write-Output "Error occurred during PSWindowsUpdate module installation. Attempting to install NuGet package provider..."
        Install-PackageProvider -Name NuGet -Force

        # Re-attempt to install PSWindowsUpdate module
        Write-Output "Re-running PSWindowsUpdate module installation..."
        Install-Module -Name PSWindowsUpdate -Force
    }
}

# Function to start the update process
function StartUpdateProcess {
    Write-Host "Start updates:"
    Get-WindowsUpdate -Verbose -Install -AcceptAll -AutoReboot
}

# Check updates
Write-Host "Check for available updates:"
Get-WindowsUpdate

# Start update process
Write-Host "Updating Windows"
StartUpdateProcess

Write-Host "Output of the last updates results:"
$results = Get-WULastResults
$lastInstallationSuccessDate = $results | Select-Object -ExpandProperty LastInstallationSuccessDate
$lastInstallationSuccessDate