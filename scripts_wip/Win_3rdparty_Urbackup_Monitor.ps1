<#
.SYNOPSIS
   Script to check the status of Urbackup file backup and log events.

.DESCRIPTION
   This script checks the status of Urbackup file backup and logs events in the Windows Event Log. It performs the following steps:
   - Checks if the UrbackupCheck parameter is enabled. If enabled, the script exits.
   - Checks if the UrBackup client is installed. If not installed, the script exits.
   - Checks if the Urbackup postfile exists. If not, it creates the file.
   - Checks if the "Write event to Event Log" line already exists in the file. If not, it adds the line.
   - Retrieves Urbackup events from the Application event log that match a specific description.
   - Determines the days elapsed since the latest event and compares it with the NumberOfDaysBeforeError parameter.
   - Displays the relevant event log information if the event is found and within the specified number of days.
   - Exits with a status code of 1 if the event is older than the specified number of days.

.PARAMETER UrbackupCheck
   Specifies whether Urbackup check is enabled or disabled. Use Custom Fields to enable or disable as needed

.PARAMETER NumberOfDaysBeforeError
   Specifies the number of days before considering an event as an error.

.EXAMPLE
   -UrbackupCheck {{agent.UrbackupDisableCheck}} -NumberOfDaysBeforeError 30

.NOTES
   Version: 1.5 6/20/2024 silversword411
#>

param (
    [Int]$UrbackupCheck,
    [Int]$NumberOfDaysBeforeError
)



#Write-Output "NumberOfDaysBeforeError: $NumberOfDaysBeforeError"

# See if Custom Field has disabled VeeamCheck
#Write-Output "VeeamCheck: $VeeamCheck"
if ($UrbackupCheck) {
    Write-Output "Urbackup check disabled."
    Exit 0
}

# Stop if Urbackup is not installed
$clientExecutable = 'C:\Program Files\UrBackup\UrBackupClient.exe'
if (-not (Test-Path -Path $clientExecutable)) {
    Write-Output "UrBackup client is not installed. Quitting"
    exit 0
}

function UpdateUrbackupPostFile {
    $file = 'C:\Program Files\UrBackup\postfilebackup.bat'
    $lineToAdd = 'EVENTCREATE /T SUCCESS /L APPLICATION /SO URBACKUP /ID 100 /D "File backup succeeded."'

    # Check if the Urbackup postfile exists
    if (-not (Test-Path -Path $file)) {
        # Create the file if it doesn't exist
        New-Item -Path $file -ItemType File | Out-Null
        Write-Output "Post backup .bat file has been created."
    }

    # Check if the line already exists in the file
    $lineExists = Get-Content -Path $file | Select-String -Pattern $lineToAdd

    if ($lineExists) {
        Write-Output "Write event to Event Log already exists in the file."
    }
    else {
        # Add the line to the file
        Add-Content -Path $file -Value $lineToAdd
        Write-Output "Write event to Event Log line has been added to the file."
    }
}

UpdateUrbackupPostFile

#########################################################################
Write-Output "------------ CHECK FOR LOG ------------"
$source = "URBACKUP"
$logName = "Application"
$eventID = 100
$description = "File backup succeeded."

$UrbackupEvents = Get-WinEvent -FilterHashtable @{
    LogName      = $logName
    ProviderName = $source
    ID           = $eventID
} | Where-Object { $_.Message -like "*$description*" } | Sort-Object TimeCreated -Descending

if ($UrbackupEvents -ne $null) {
    $latestEvent = $UrbackupEvents[0]
    $daysSinceEvent = (Get-Date) - $latestEvent.TimeCreated
    if ($daysSinceEvent.Days -gt $NumberOfDaysBeforeError) {
        Write-Output "WARNING: The last event is older than $NumberOfDaysBeforeError days."
        Write-Output "Last Backup: $($latestEvent.TimeCreated)"
        exit 1
    }
    else {
        Write-Output "ALL GOOD: The last event is newer than $NumberOfDaysBeforeError days."
        #Write-Output "Event Log found:"
        #Write-Output "Source: $($latestEvent.ProviderName)"
        #Write-Output "Event ID: $($latestEvent.Id)"
        #Write-Output "Message: $($latestEvent.Message)"
        Write-Output "Last Backup: $($latestEvent.TimeCreated)"
    }
}
else {
    Write-Output "Event Log not found."
}