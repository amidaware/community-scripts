<#
.SYNOPSIS
    Poor's man WSUS/SCCM part 3 - Module Updates
    This PowerShell script is the third phase of a multi-part automation process, focusing on updating PowerShell modules installed from the PSGallery. 
    It is designed to run daily to ensure all modules are up to date and log the update process for tracking purposes.

.DESCRIPTION
    The script performs the following actions:
    * Runs daily
    * Uses the `Updater P3.5 Schedules parser` snippet to parse and check if module updates are scheduled for the current date.
    * Logs update results using the `Logging` snippet.

    For each installed module, the script attempts to update it using the `Update-Module` cmdlet. It then logs the version information of all updated modules for tracking purposes.
.EXAMPLE
    Schedules={{agent.Schedules}}
    Company_folder_path={{global.Company_folder_path}}

.NOTES
    Author: SAN // MSA
    Date: 06.08.24
    Dependencies: 
        Logging snippet for logging
        Updater P3.5 Schedules parser snippet for parsing the date
        CallPowerShell7 snippet to upgrade the script to pwsh
    #public

.CHANGELOG
    13.12.24 SAN Split logging from parser.
    
#>


# Name will be used for both the name of the log file and what line of the Schedules to parse
$PartName = "ModuleUpdate"

# Call the parser snippet env Schedules will be passed
{{Updater P3.5 Schedules parser}}

# Call the logging snippet env Company_folder_path will be passed
{{Logging}}

# Call the pwsh snippet
{{CallPowerShell7}}

# Set TLS version to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Update installed modules from PSGallery
Get-InstalledModule | ForEach-Object {
Write-Host "Updating module: $($_.Name)"
Update-Module -Name $_.Name -Force
}

# Display last updates information
$installedModules = Get-InstalledModule
foreach ($module in $installedModules) {
    "Module: $($module.Name) - Version: $($module.Version)"
}