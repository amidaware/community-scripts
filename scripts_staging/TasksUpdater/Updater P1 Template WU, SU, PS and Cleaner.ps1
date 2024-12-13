<#
.SYNOPSIS
    Poor's man WSUS/SCCM part 1
    This PowerShell script is the first part of a multi-phase automation process designed to manage and schedule system maintenance tasks based on device attributes, primarily focusing on the hostname. 
    In this phase, the script outputs the device's category (e.g., DC, DB, APP) and odd/even status, as well as generates initial schedules for updates and cleanup tasks, which will be used in the subsequent parts of the process to refine and manage these tasks based on device-specific criteria.

.DESCRIPTION
    The script begins by checking the value of the environment variable `CurrentSchedules` to determine if the script should be executed or skipped. 
    If the variable contains the word "skip" or the environment variable `forcechange` is not set to "true", the script exits early. 
    If the script proceeds, it retrieves and outputs the hostname of the device and the current date.

    The device's category is determined by matching the hostname against predefined keywords for various roles such as Domain Controller (DC), Database Server (DB), Application Server (APP), Remote Desktop Server (RDS), and Exchange Server. 
    The script then calculates the sum of digits in the hostname to classify the device as "Odd" or "Even", which will influence the update schedule.

    Based on the device's category and odd/even classification, the script assigns specific weeks and days for key maintenance tasks:
    * Windows updates
    * Software updates
    * PowerShell module updates
    * Temporary file cleanup

    The script outputs these initial schedules, using the last digit of the hostname to determine the exact time for each task in a `HH:mm:ss` format. 
    These schedules will serve as a foundation for the next phase of automation.

.EXEMPLE
    CurrentSchedules={{agent.SchedulesTemplate}}
    forcechange=false

.NOTES
    Author: SAN // MSA
    Date: 01.01.24
    #public

.CHANGELOG
    04.09.24 SAN Refactored to determine device categories and odd/even status for scheduling purposes.

.TODO
    add debug flag to env
    rename env CurrentSchedules to env CurrentTemplate and CurrentSchedules to ExistingTemplate


#>


$Debug = $false

# Check if forcechange is not "true" or if CurrentSchedules contains "skip" or "lock"
# lock and skip check is to avoid unforcene changes dues to an onboarding task overwriting important client information when a variable has been customised manualy
if ($Env:forcechange -ne "true" -or $Env:CurrentSchedules -match "skip|lock") {
    # Check if CurrentSchedules exists and does not contain "Collected"
    # "collected" is part of our default value for the field so it should be ignored when found and generate a new set of values.

    if ($Env:CurrentSchedules -ne $null -and $Env:CurrentSchedules -notmatch "Collected") {
        # Cleanup of the variable in case empty lines have been added.

        # Split CurrentSchedules into lines, filter out lines containing "CurrentSchedules"
        $filteredLines = $Env:CurrentSchedules -split "`n" | Where-Object { $_ -notmatch "CurrentSchedules" }
        
        # Join the lines, trim extra spaces, and remove consecutive line breaks
        $cleanedOutput = ($filteredLines -join "`n").Trim() -replace "(\r?\n){2,}", "`n"
    
        # Output the cleaned string
        Write-Host $cleanedOutput
        
        # Exit the script
        exit 0
    }
}




# Get the hostname of the device
$hostname = [System.Net.Dns]::GetHostName()

# Output the hostname
if ($Debug) { Write-Output "Hostname: $hostname" }

# Get the current date
$currentDate = Get-Date

# Output the current date and the name of the day with its occurrence in the month
$currentDay = $currentDate.DayOfWeek
$occurrenceInMonth = [math]::Ceiling($currentDate.Day / 7)
if ($Debug) {
    Write-Output "Current Date: $($currentDate.ToString('MM/dd/yyyy'))"
    Write-Output "Current Day: $($currentDay.ToString()) (Occurrence in Month: $occurrenceInMonth)"
    Write-Output "-----------------------------------"
}

# Define keywords for each category
$categories = @{
    "DC" = @("DC", "AD")
    "DB" = @("SQL", "DB")
    "APP" = @("IIS", "WEB", "APP")
    "RDS" = @("RDS", "Broker")
    "Exchange" = @("exch", "MBX")
}

# Determine the device category based on keywords in the hostname
$deviceCategory = "Unidentified"
try {
    $foundCategory = $false
    foreach ($category in $categories.Keys) {
        foreach ($keyword in $categories[$category]) {
            if ($hostname -like "*$keyword*") {
                $deviceCategory = $category
                $foundCategory = $true
                break
            }
        }
        if ($foundCategory) {
            break
        }
    }
} catch {
    Write-Host "Error occurred while determining device category: $_"
}

# Output the device category
if ($Debug) { Write-Output "Device Category: $deviceCategory" }

# Function to calculate the sum of digits in a string
function Get-DigitSum($inputString) {
    $sum = 0
    foreach ($char in $inputString.ToCharArray()) {
        if ($char -match '\d') {
            $sum += [int]$char
        }
    }
    return $sum
}

# Calculate the sum of digits in the hostname
$digitSum = Get-DigitSum $hostname

if ($Debug) { Write-Output "Device sum of digits: $digitSum"  }

# Determine if the device is odd or even
if ($digitSum % 2 -eq 0) {
    $oddEven = "Even"
} else {
    $oddEven = "Odd"
}

# Output if the device is odd or even
if ($Debug) { Write-Output "Device Sum: $oddEven" }

Write-Output "$deviceCategory $oddEven"

switch -Regex ($deviceCategory + $oddEven) {
    "DCEven" {
        $windowsUpdateDay = "3rd Tuesday"
        $softwareUpdateDay = "1st Tuesday"
        $tempFileCleanupDay = "4th Tuesday"
        $powershellUpdateDay = "2nd Tuesday"
    }
    "DCOdd" {
        $windowsUpdateDay = "2nd Tuesday"
        $softwareUpdateDay = "4th Tuesday"
        $tempFileCleanupDay = "3rd Tuesday"
        $powershellUpdateDay = "1st Tuesday"
    }
    "DBEven" {
        $windowsUpdateDay = "1st Wednesday"
        $softwareUpdateDay = "3rd Wednesday"
        $tempFileCleanupDay = "4th Wednesday"
        $powershellUpdateDay = "2nd Wednesday"
    }
    "DBOdd" {
        $windowsUpdateDay = "2nd Wednesday"
        $softwareUpdateDay = "4th Wednesday"
        $tempFileCleanupDay = "1st Wednesday"
        $powershellUpdateDay = "3rd Wednesday"
    }
    "APPEven" {
        $windowsUpdateDay = "3rd Thursday"
        $softwareUpdateDay = "1st Thursday"
        $tempFileCleanupDay = "4th Thursday"
        $powershellUpdateDay = "2nd Thursday"
    }
    "APPOdd" {
        $windowsUpdateDay = "2nd Thursday"
        $softwareUpdateDay = "4th Thursday"
        $tempFileCleanupDay = "1st Thursday"
        $powershellUpdateDay = "3rd Thursday"
    }
    "RDSEven" {
        $windowsUpdateDay = "4th Tuesday"
        $softwareUpdateDay = "1st Tuesday"
        $tempFileCleanupDay = "2nd Tuesday"
        $powershellUpdateDay = "3rd Tuesday"
    }
    "RDSOdd" {
        $windowsUpdateDay = "3rd Tuesday"
        $softwareUpdateDay = "2nd Tuesday"
        $tempFileCleanupDay = "4th Tuesday"
        $powershellUpdateDay = "1st Tuesday"
    }
    "ExchangeEven" {
        $windowsUpdateDay = "4th Wednesday"
        $softwareUpdateDay = "2nd Wednesday"
        $tempFileCleanupDay = "3rd Wednesday"
        $powershellUpdateDay = "1st Wednesday"
    }
    "ExchangeOdd" {
        $windowsUpdateDay = "3rd Wednesday"
        $softwareUpdateDay = "1st Wednesday"
        $tempFileCleanupDay = "4th Wednesday"
        $powershellUpdateDay = "2nd Wednesday"
    }
    default {
        $windowsUpdateDay = "4th Thursday"
        $softwareUpdateDay = "2nd Thursday"
        $tempFileCleanupDay = "3rd Thursday"
        $powershellUpdateDay = "1st Thursday"
    }
}


# Function to get scheduled time based on the last digit of hostname
function Get-ScheduledTime($lastDigit) {
    switch ($lastDigit) {
        {$_ -eq 0 -or $_ -eq 9} {
            Get-Date -Hour 2 -Minute 30 -Second 0
        }
        {$_ -eq 1 -or $_ -eq 2} {
            Get-Date -Hour 3 -Minute 0 -Second 0
        }
        {$_ -eq 3 -or $_ -eq 4} {
            Get-Date -Hour 4 -Minute 30 -Second 0
        }
        {$_ -eq 5 -or $_ -eq 6} {
            Get-Date -Hour 3 -Minute 30 -Second 0
        }
        {$_ -eq 7 -or $_ -eq 8} {
            Get-Date -Hour 4 -Minute 00 -Second 0
        }
        default {
            Get-Date -Hour 2 -Minute 0 -Second 0
        }
    }
}

# Get the last digit of the hostname
$secondDigit = $null
foreach ($char in $hostname.ToCharArray()) {
    if ($char -match '\d') {
        if ($secondDigit -eq $null) {
            $secondDigit = $char
        } else {
            $secondDigit += $char
            break
        }
    }
}
$lastDigit = [int]$secondDigit

# Get the scheduled time based on the last digit
$scheduledTime = Get-ScheduledTime $lastDigit

# Output the time attributed
if ($Debug) { Write-Output "Time: $scheduledTime" }

$dateTime = [datetime]$scheduledTime

$timeOnly = $dateTime.ToString('HH:mm:ss')


Write-Host "WindowsUpdate: $windowsUpdateDay $timeOnly"
Write-Host "SoftwareUpdate: $softwareUpdateDay $timeOnly"
Write-Host "ModuleUpdate: $powershellUpdateDay $timeOnly"
Write-Host "tempFileCleanup: $tempFileCleanupDay $timeOnly"