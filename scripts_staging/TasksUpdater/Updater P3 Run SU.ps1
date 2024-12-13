<#
.SYNOPSIS
    Poor's man WSUS/SCCM part 3 - Software Update
    This PowerShell script is the third phase of a multi-part automation process. 
    It manages the daily software update process, identifies pending system reboots, and schedules a reboot if necessary after completing updates.
    It is designed to run daily to ensure all modules are up to date and log the update process for tracking purposes.

.DESCRIPTION
    This script is designed to ensure systems are kept up to date with minimal disruption:
    * Run daily
    * Uses the `Updater P3.5 Schedules parser` snippet to determine the current task's schedule.
    * Logs all actions and outputs through the `Logging` snippet for troubleshooting and auditing.
    * Leverages Chocolatey to identify outdated software packages and upgrades them.
    * Automatically schedules a reboot if required, using the parsed time from the schedule.

.EXAMPLE
    Schedules={{agent.Schedules}}
    Company_folder_path={{global.Company_folder_path}}

.NOTES
    Author: SAN // MSA
    Date: 06.08.2024
    Dependencies: 
        Logging snippet for logging
        Updater P3.5 Schedules parser snippet for parsing the date
        CallPowerShell7 snippet to upgrade the script to pwsh
    #public

.CHANGELOG 
    24.10.24 SAN Conditional reboot added and removed the reboot snippet; this part is going to be canned.
    28.10.24 SAN Added even flag for reboot.
    04.11.24 SAN More verbose output for the reboot to help troubleshoot.
    27.11.24 SAN More verbose output for the reboot and fixed some lack of logs from the Chocolatey commands.
    27.11.24 SAN Disabled file rename check due to issues.
    13.12.24 SAN Split logging from parser.

.TODO
    Fix rename?
#>


# Name will be used for both the name of the log file and what line of the Schedules to parse
$PartName = "SoftwareUpdate"

# Call the parser snippet env Schedules will be passed
{{Updater P3.5 Schedules parser}}

# Call the logging snippet env Company_folder_path will be passed
{{Logging}}

# Function to check if a reboot is pending and return reasons
function Get-PendingReboot {
    $rebootRequired = $false
    $reasons = @()  # Array to store reasons for reboot

    # Check for Windows Update reboot required
    $WUReboot = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
    if ($WUReboot) {
        $reasons += "Windows Update requires a reboot."
        $rebootRequired = $true
    }

    # DISABLED DUE TO FALSE POSITIVE
    # Check for pending file rename operations
    # $PendingFileRenameOperations = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($PendingFileRenameOperations) {
        $reasons += "Pending file rename operations require a reboot."
        $rebootRequired = $true
    }

    # Check if Component-Based Servicing (CBS) requires a reboot
    $CBSReboot = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
    if ($CBSReboot) {
        $reasons += "Component-Based Servicing requires a reboot."
        $rebootRequired = $true
    }

    # Check for pending computer rename
    $ComputerRename = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -ErrorAction SilentlyContinue
    $PendingComputerRename = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -ErrorAction SilentlyContinue
    if ($ComputerRename -and $PendingComputerRename -and ($ComputerRename.ComputerName -ne $PendingComputerRename.ComputerName)) {
        $reasons += "Computer rename operation requires a reboot."
        $rebootRequired = $true
    }

    # Check if Windows Installer (MSI) requires a reboot
    $PendingMSIReboot = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress" -ErrorAction SilentlyContinue
    if ($PendingMSIReboot) {
        $reasons += "Windows Installer (MSI) operation requires a reboot."
        $rebootRequired = $true
    }

    # Check if Group Policy client requires a reboot
    $GPReboot = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\RebootRequired" -ErrorAction SilentlyContinue
    if ($GPReboot) {
        $reasons += "Group Policy changes require a reboot."
        $rebootRequired = $true
    }

    # Check for pending package installations
    $PendingPackageInstalls = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Updates" -ErrorAction SilentlyContinue
    if ($PendingPackageInstalls) {
        $reasons += "Pending package installations require a reboot."
        $rebootRequired = $true
    }

    # Return an object with reboot status and reasons
    return [PSCustomObject]@{
        RebootRequired = $rebootRequired
        Reasons        = $reasons
    }
}

# check if reboot is needed
$result = Get-PendingReboot
if ($result.RebootRequired) {
    Write-Host "Reboot is pending BEFORE updates for the following reasons:"
    $result.Reasons | ForEach-Object { Write-Host "- $_" }
} else {
    Write-Host "No Reboot is pending BEFORE updates."
}

# The following section is in place due to the fact that ps logging does not capture RAW output from choco
# List outdated packages and capture output
$outdatedPackages = choco outdated | Out-String
# Upgrade all packages and capture output
$upgradeResult = choco upgrade all -y | Out-String

Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host ""
Write-Host "Outdated Packages:"
Write-Host $outdatedPackages
Write-Host "------------------------------------------------------------"
Write-Host "Upgrade Result:"
Write-Host $upgradeResult
Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host ""


# Check if a reboot is pending and reboot if necessary
$result = Get-PendingReboot
if ($result.RebootRequired) {
    Write-Host "Reboot is pending AFTER update for the following reasons:"
    $result.Reasons | ForEach-Object { Write-Host "- $_" }

    Write-Host "The system will reboot at $scheduledTime."
    $timeDifference = New-TimeSpan -Start (Get-Date) -End $scheduledTime
    $SetReboot = [int]$timeDifference.TotalSeconds

    # Schedule the system reboot
    Write-Host "shutdown.exe /r /f /t $SetReboot /c Reboot done by RMM task, required after packages updates /d p:4:1"
    shutdown.exe /r /f /t $SetReboot /c "Reboot done by RMM task, required after packages updates" /d p:4:1
    
    # Output a warning message
    $minutes = [math]::Floor($SetReboot / 60) # Rounding 
    $Message = "The system will reboot in $minutes minutes. Please save your work."
    Write-Host $Message
    msg * $Message
    exit 0

} else {
    Write-Host "No reboot is pending. Exiting gracefully"
    exit 0
}