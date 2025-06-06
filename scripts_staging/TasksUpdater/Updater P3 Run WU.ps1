<#
.SYNOPSIS
    Poor's man WSUS/SCCM part 3 - Windows Update
    This PowerShell script is the third phase of a multi-part automation process for managing system maintenance tasks. 
    It checks and executes scheduled tasks for Windows updates, using the dates and times generated in the second phase. 
    This script ensures that the updates are installed at the specified time and date and reboots the system if required.
    It is designed to run daily but will only execute the windows updates on the parsed day otherwise will simply display the last log.
    It also manages a blacklist of KBs to prevent their installation, with validation of the provided KBs to ensure correct format.

.DESCRIPTION
    The script processes tasks by:
    * Runs Daily
    * Parsing schedules using the `Updater P3.5 Schedules parser` snippet to determine the next applicable date and time for updates.
    * Logging actions and results using the `Logging` snippet.
    * Ensuring compatibility with PowerShell 7 through the `CallPowerShell7` snippet.
    * Prevents installation of blacklisted KBs by hiding them using `Hide-WindowsUpdate`.

    The script validates the availability of the `PSWindowsUpdate` module, installing it if necessary. 

.EXAMPLE
    Schedules={{agent.Schedules}}
    Company_folder_path={{global.Company_folder_path}}
    BLACKLISTED_KBS=KB1234567,KB1234567,KB1234567

.NOTES
    Author: SAN // MSA
    Date: 13.12.2024
    Dependencies: 
        Logging snippet for logging
        Updater P3.5 Schedules parser snippet for parsing the date
        CallPowerShell7 snippet to upgrade the script to pwsh
    #public
    
.CHANGELOG
    04.10.24 SAN Removed last output; the data is non-sense.
    13.12.24 SAN Split logging from parser.
    30.01.25 SAN Changed output for troubleshooting
    14.04.25 SAN Added validation for KB format and warnings for invalid KBs.
    03.06.25 SAN move PS7 call at the start
#>

# Call the pwsh snippet
{{CallPowerShell7}}

# Name will be used for both the name of the log file and what line of the Schedules to parse
$PartName = "WindowsUpdate"

# Call the parser snippet env Schedules will be passed
{{Updater P3.5 Schedules parser}}

# Call the logging snippet env Company_folder_path will be passed
{{Logging}}

# Set TLS version to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# Check if PSWindowsUpdate module is available
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    #Write-Output "PSWindowsUpdate is already installed"
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

# Hide KB to avoid installations
$kbList = @()
if ($env:BLACKLISTED_KBS) { $kbList += $env:BLACKLISTED_KBS -split ',' | ForEach-Object { $_.Trim() } }

$kbList = $kbList | ForEach-Object {
    if ($_ -match '^KB\d{7}$') { $_ }
    else { Write-Warning "Invalid KB format: '$_'"; $null }
} | Select-Object -Unique

foreach ($kb in $kbList) {
    Write-Host "Hiding $kb..."
    Hide-WindowsUpdate -KBArticleID $kb -Verbose
}


# Run Windows update with PSWindowsUpdate and rebooting at time found in parser
Write-Host "Running windows updates:"
Write-Host "Get-WindowsUpdate -Verbose -Install -AcceptAll -AutoReboot -ScheduleReboot $scheduledTime"
Get-WindowsUpdate -Verbose -Install -AcceptAll -AutoReboot -ScheduleReboot $scheduledTime
