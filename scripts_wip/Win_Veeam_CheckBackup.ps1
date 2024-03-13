<#
    .SYNOPSIS
        Using Events log "Veeam Agent", makes sure veeam is installed. Then make sure you haven't disabled Veeam checks. Then looks to see if there's a warning about last backup (in the last 24hrs). If no warning, then gets date of last backup and displays. Needs to run every 24hrs.
    .DESCRIPTION
        Run it daily. It'll error and return 1 if any of these conditions: No backup in 10 days (customizable per agent), backup drive not NTFS, increases Veeam log max size for more data, errors if less than 10GB free space on backup drive.
    .PARAMETER -VeeamCheck
        -VeeamCheck {{agent.VeeamDisableCheck}} 
        Make a Custom Field | For Agents | Called "VeeamDisableCheck" of type checkbox, with default of false. When you don't want the veeamcheck to run on an agent flip the switch and the script won't error, it'll just bypass that agent completely.
    .PARAMETER -NumberOfDaysBeforeError
        -VeeamCheck {{agent.VeeamDaysBeforeError}} 
        Make a Custom Field | For Agents | Called "VeeamDaysBeforeError" of type Number, with default of empty. Use this to set the number of days with no backup before script goes from pass to error. Line 40 is number of days by default: 10
    .NOTES
        2/2022 v1 Initial release by @silversword411
        6/22/2023 v1.1 setting NumberOfDaysBeforeError using Custom Fields
        10/2023 v1.5 Toast function added. Still needs regression testing before activating
        12/20/2023 v1.8 Adding CheckBackupDriveSpace Script will error if backup drive free space less than 10GB
        12/28/2023 v1.9 Adding Set-EventLogMaxSize to change Veeam Event log max size from 512k to 10MB
  #>

#-VeeamCheck {{agent.VeeamDisableCheck}}
#-NumberOfDaysBeforeError {{agent.VeeamDaysBeforeError}}

param(
    [Int]$VeeamCheck,
    [Int]$NumberOfDaysBeforeError,
    [Int]$VeeamEventLogSize,
    [switch]$debug
)

#$PSBoundParameters

if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

if ($NumberOfDaysBeforeError -eq "") {
    $NumberOfDaysBeforeError = 10
}
    

$logName = "Veeam Agent"
# ------------------------------------


Write-Debug "NumberOfDaysBeforeError: $NumberOfDaysBeforeError"
#Write-Debug "Command line arguments splatting `$args:", $($args)
Write-Debug "args: $args"

Write-Output "----------------- INFO AND CHECK FOR PROBLEMS ----------------"  
# Look for backup drive and make sure it's NTFS. Anything else and any restore will fail
#$Drive = get-psdrive | where { $_.Root -match ":" } | % { if (Test-Path ($_.Root + "VeeamBackup")) { $_.Root } }
$Drive = Get-PSDrive | Where-Object { $_.Root -match ":" } | ForEach-Object {
    if (Test-Path ($_.Root + "VeeamBackup")) {
        $_.Root.Substring(0, 1) # return only the first letter of the root
        #break innerloop
    }
} | Select-Object -Unique


Write-Debug "Backup drive is $Drive"

if ([string]::IsNullOrEmpty($Drive)) {
    Write-Debug "Backup drive not connected. Test for FileSystem type later."
}
else {
    $DriveFS = (Get-Volume -DriveLetter $Drive).FileSystem
    Write-Debug "Backup Drive File System: $DriveFS"
  
    if ($DriveFS -ne "NTFS") {
        Write-Output "WARNING*WARNING*WARNING: Backup Drive isn't NTFS. Rebuild backup drive!!!"
        Exit 1
    }
}

# See if Custom Field has disabled VeeamCheck
Write-Debug "VeeamCheck: $VeeamCheck"
if ($VeeamCheck) {
    Write-Output "Veeam check disabled."
    Exit 0
}

# Make sure Veeam is installed
if (-not(Test-Path -Path "C:\Program Files\Veeam\Endpoint Backup")) {
    Write-Output "Veeam not installed."
    Exit 0
}

function CheckBackupDriveSpace {
    # Get the drive information
    $driveInfo = Get-PSDrive -Name $drive

    # Check if the drive exists
    if ($null -eq $driveInfo) {
        Write-Output "Drive $drive does not exist."
        return
    }

    # Convert free space to GB and format it with two decimal places
    $freeSpaceGB = [math]::Round(($driveInfo.Free / 1GB), 2)

    # Convert 10GB to bytes (1GB = 1073741824 bytes)
    $requiredSpace = 10 * 1073741824

    # Check if the free space is less than 10GB
    if ($driveInfo.Free -lt $requiredSpace) {
        Write-Output "WARNING*WARNING*WARNING Drive $drive has only $freeSpaceGB GB free space, which is less than 10GB."
    }
    else {
        Write-Debug "Drive $drive has $freeSpaceGB GB free space."
    }
}



# Get Veeam version
$Path = "C:\Program Files\Veeam\Endpoint Backup\Veeam.Backup.Core.dll" # Path to Veeam.Backup.Core.dll by default it's located in C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Core.dll
$Item = Get-Item -Path $Path
#$Item.VersionInfo.ProductVersion
#$item.VersionInfo.FileVersion
#$item.VersionInfo.Comments
Write-Debug "Veeam Installed: v$($Item.VersionInfo.ProductVersion)"

function ToastAlerts {
    #Needs testing
    Write-Debug "last_successful_backup: $last_successful_backup"
    Write-Debug "backup_time: $backup_time"
    Write-Debug "days_since_last_backup: $days_since_last_backup"
    Write-Debug "days_since_last_backup_dint: $days_since_last_backup_dint"

    function InstallToastRequirements {
        # Check if NuGet is installed
        if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
            Write-Output "Nuget installing"
            Install-PackageProvider -Name NuGet -Force
        }
        else {
            Write-Debug "Nuget already installed"
        }
    
        if (-not (Get-Module -Name BurntToast -ListAvailable)) {
            Write-Output "BurntToast installing"
            Install-Module -Name BurntToast -Force
        }
        else {
            Write-Debug "BurntToast already installed"
        }

        if (-not (Get-Module -Name RunAsUser -ListAvailable)) {
            Write-Output "RunAsUser installing"
            Install-Module -Name RunAsUser -Force
        }
        else {
            Write-Debug "RunAsUser already installed"
        }
    }
    InstallToastRequirements

    function TRMMTempFolder {
        # Make sure the temp folder exists
        If (!(test-path $env:ProgramData\TacticalRMM\temp)) {
            New-Item -ItemType Directory -Force -Path "$env:ProgramData\TacticalRMM\temp"
        }
        Else {
            Write-Debug "TRMM Temp folder exists"
        }
    }
    TRMMTempFolder

    # Used to store text to show user and use inside the script block. Currently untested 2/22/2024
    Set-Content -Path $env:ProgramData\TacticalRMM\temp\toastmessage.txt -Value "Your external backup hasn't run since $backup_time ($days_since_last_backup_dint days). Please connect drive so it can update. Call if you have questions: 770-778-1672"

    Invoke-AsCurrentUser -scriptblock {
        $messagetext = Get-Content -Path $env:ProgramData\TacticalRMM\temp\toastmessage.txt
        $heroimage = New-BTImage -Source 'https://fixme/Logo9a.png' -HeroImage
        $Text1 = New-BTText -Content  "Message from xyz"
        $Text2 = New-BTText -Content "$messagetext"
        $Button = New-BTButton -Content "Snooze" -snooze -id 'SnoozeTime'
        $Button2 = New-BTButton -Content "Dismiss" -dismiss
        $5Min = New-BTSelectionBoxItem -Id 5 -Content '5 minutes'
        $10Min = New-BTSelectionBoxItem -Id 10 -Content '10 minutes'
        $1Hour = New-BTSelectionBoxItem -Id 60 -Content '1 hour'
        $4Hour = New-BTSelectionBoxItem -Id 240 -Content '4 hours'
        $1Day = New-BTSelectionBoxItem -Id 1440 -Content '1 day'
        $Items = $5Min, $10Min, $1Hour, $4Hour, $1Day
        $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 10 -Items $Items
        $action = New-BTAction -Buttons $Button, $Button2 -inputs $SelectionBox
        $Binding = New-BTBinding -Children $Text1, $Text2 -HeroImage $heroimage
        $Visual = New-BTVisual -BindingGeneric $Binding
        $Content = New-BTContent -Visual $Visual -Actions $action
        Submit-BTNotification -Content $Content
    }

    # Cleanup temp file for message variables
    Remove-Item -Path $env:ProgramData\TacticalRMM\temp\toastmessage.txt
}
# ToastAlerts


If ($Debug) {
    Write-Output "=================== DEBUG ==================="

    $ErrorActionPreference = 'silentlycontinue'

    $total_events = Get-EventLog -LogName $logName | Measure-Object | Select-Object -ExpandProperty Count
    Write-Output "Total Events in Veeam Log: $total_events"

    $currentMaxSize = (Get-EventLog -List | Where-Object { $_.Log -eq $logName }).MaximumKilobytes
    Write-Output "Current Maximum Size: $currentMaxSize KB"
  

    $oldest_event = Get-WinEvent -FilterHashtable @{LogName = $logName } | Sort-Object -Property TimeCreated | Select-Object -First 1 -ExpandProperty TimeCreated
    Write-Output "Oldest Event in Veeam Log: $oldest_event"

    Write-Output "-----------------------"
    $oldest_errorevent = Get-EventLog $logName -EntryType Error -InstanceId 190 -newest 1
    if ($oldest_errorevent) {
        $lasterrortime = $oldest_errorevent.TimeGenerated
        Write-Output "Last Error Backup: $lasterrortime"
        Get-EventLog $logName -EntryType Error -InstanceId 190 -newest 1 | Format-List TimeGenerated, InstanceID, EntryType, Message
    }
    else {
        Write-Output "No error events found."
    }

    Write-Output "-----------------------"
    $last_warning_event = Get-EventLog $logName -EntryType Information, Warning -InstanceId 190 -newest 1
    if ($last_warning_event) {
        $last_warning_time = $last_warning_event.TimeGenerated
        Write-Output "Last Warning Successful Backup: $last_warning_time"
        $last_warning_event | Format-List TimeGenerated, InstanceID, EntryType, Message
    }
    else {
        Write-Output "No warning events found."
    }

    Write-Output "-----------------------"
    $last_success_event = Get-EventLog $logName -EntryType Information -InstanceId 190 -newest 1
    if ($last_success_event) {
        $last_success_time = $last_success_event.TimeGenerated
        Write-Output "Last Successful Backup: $last_success_time"
        $last_success_event | Format-List TimeGenerated, InstanceID, EntryType, Message
    }
    else {
        Write-Output "No successful backup events found."
    }
    Write-Output "================= END DEBUG ================="
}

function Set-EventLogMaxSize {
    param (
        [int]$NewMaxSizeMB = 10
    )
    
    $logName = "Veeam Agent"

    $currentMaxSize = (Get-EventLog -List | Where-Object { $_.Log -eq $LogName }).MaximumKilobytes
    Write-Debug "Current Maximum Size: $currentMaxSize KB"

    $desiredMaxSize = $NewMaxSizeMB * 1MB

    if (($currentMaxSize * 1024) -ne $desiredMaxSize) {
        Write-Output "Changing to $NewMaxSizeMB MB."
        Limit-EventLog -LogName $LogName -MaximumSize $desiredMaxSize
    } else {
        Write-Debug "No change necessary."
    }
}

$currentMaxSize = (Get-EventLog -List | Where-Object { $_.Log -eq $LogName }).MaximumKilobytes
If ($currentMaxSize -eq 512) {
    Write-Output "Current Size test = 512KB, going to make it bigger"
    Set-EventLogMaxSize
}


Write-Output "------------- Veeam Backup Data --------------"  

Write-Debug "Error if no backup within this number of days: $NumberOfDaysBeforeError"
$date_to_check = (Get-Date).AddDays(-$NumberOfDaysBeforeError)

$oldest_event = Get-WinEvent -FilterHashtable @{LogName = $logName } | Sort-Object -Property TimeCreated | Select-Object -First 1 -ExpandProperty TimeCreated
$oldest_event_formatted = $oldest_event.ToString("yyyy-MM-dd HH:mm:ss")
Write-Debug "Oldest Event in Veeam Log: $oldest_event_formatted"

$date_to_check_formatted = $date_to_check.ToString("yyyy-MM-dd HH:mm:ss")
Write-Debug "Date to Check back to: $date_to_check_formatted"

$last_successful_backup = Get-EventLog $logName -EntryType Information, Warning -InstanceId 190 -newest 1
$backup_time = $last_successful_backup.TimeGenerated.ToString("yyyy-MM-dd HH:mm:ss")
Write-Output "Last Successful backup: $backup_time"

if ($last_successful_backup.TimeGenerated -lt $date_to_check) {
    if ($backup_time -eq $null) {
        Write-Output "WARNING*WARNING*WARNING: Last successful backup was UNKNOWN. Investigate!" 
    }
    else {
        $days_since_last_backup = (Get-Date) - $last_successful_backup.TimeGenerated
        $days_since_last_backup = $days_since_last_backup.Days
        Write-Output "WARNING*WARNING*WARNING: Last successful backup was $($last_successful_backup.TimeGenerated) : $days_since_last_backup days ago"
        Write-Output "That's more than $NumberOfDaysBeforeError days ago. Investigate!"
        
        Get-EventLog "Veeam Agent" -newest 1 -After (Get-Date).AddDays(-1) | Format-List TimeGenerated, InstanceID, EntryType, Message
    }
    CheckBackupDriveSpace
    Exit 1
}
else {
    Write-Output "GOOD: Last successful backup on $($last_successful_backup.TimeGenerated) was less than $NumberOfDaysBeforeError days ago. All good!"
    #$last_successful_backup.TimeGenerated
    Exit 0
}