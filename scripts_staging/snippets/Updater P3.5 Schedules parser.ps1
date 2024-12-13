<#
.SYNOPSIS
This PowerShell script checks whether a specific part's schedule is due for today based on a provided schedule string. 
It retrieves and parses schedules, determines if the schedule matches the current date, and outputs relevant information. 
If the schedule is set to "skip" or is not found, the script exits with appropriate messages.

.DESCRIPTION
The script attempts to retrieve the scheduled time for the part using the Get-CheckSchedule function. If an error occurs during this process, it outputs an error message and exits with a status code of 1.

After retrieving the schedule, it checks if the schedule is for today using the Is-ScheduleForToday function. Based on the result:
* If the schedule is for today, it outputs a message indicating that the schedule is due today and provides the scheduled update time.
* If the schedule is not for today, it informs the user of the number of days until the schedule and exits.

This script is useful for validating and managing update schedules for specific parts, ensuring timely execution of scheduled tasks based on current dates.

.NOTES
    Author: MSA/SAN
    Date: 12.08.2024
    #public

.Changelog
    SAN corrected some bugs and added logging function
    added a lot of debug
    Fixed log output on other days
    27.11.24 SAN Added more output
    27.11.24 SAN changed log-rotate logic
    13.12.24 SAN Moved logging to another script

.TODO
    Change date to dd/MM/YYYY in both this script and the P2

#>

$Debug = 0  # Set to 1 to enable debug output, 0 to disable
$Schedules = $env:SCHEDULES


function Get-CheckSchedule {
    param(
        [string]$Schedules,
        [string]$PartName
    )

    if ($Debug -eq 1) {
        Write-Host "Debug: Received Schedules: $Schedules"
        Write-Host "Debug: Received PartName: $PartName"
    }

    # Normalize newline characters and split into lines
    $scheduleLines = $Schedules -replace "`r`n", "`n" -replace "`r", "`n" -split "`n"
    
    if ($Debug -eq 1) {
        Write-Host "Debug: Split schedule lines:"
        $scheduleLines | ForEach-Object { Write-Host "Debug: $_" }
    }

    foreach ($line in $scheduleLines) {
        $line = $line.Trim()
        
        if ($Debug -eq 1) {
            Write-Host "Debug: Processing line: '$line'"
        }

        if ($line -match "^$($PartName):skip.*$") {
            if ($Debug -eq 1) {
                Write-Host "Debug: Skip pattern detected. Exiting function."
            }
            Write-Host "$PartName lines contains skip exiting as per requirement"
            exit 0
        }

        elseif ($line -match "^$($PartName):(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2})$") {
            $updateTime = $matches[1]
            if ($Debug -eq 1) {
                Write-Host "Debug: Found date-time pattern: $updateTime"
            }
            
            try {
                $scheduledTime = [datetime]::ParseExact($updateTime, 'MM/dd/yyyy HH:mm:ss', $null)
                if ($Debug -eq 1) {
                    Write-Host "Debug: Parsed scheduled time: $scheduledTime"
                }
                return $scheduledTime
            } catch {
                if ($Debug -eq 1) {
                    Write-Host "Debug: Error parsing date-time: $_"
                }
                Write-Host "Error parsing date-time."
                exit 1
            }
        }
    }

    if ($Debug -eq 1) {
        Write-Host "No $PartName schedule found."
        Write-Host "Debug: No schedule found for $PartName."
    }
    Write-Host "No schedule found for $PartName."
    exit 1
}

# Function to check if the schedule is for today
function Is-ScheduleForToday {
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$ScheduledTime
    )

    $today = Get-Date
    $scheduleDate = $ScheduledTime.Date
    $daysDifference = ($scheduleDate - $today.Date).Days
    $isToday = $daysDifference -eq 0
    return $isToday, $daysDifference
}

# Function that will get the last log entry when the parsed day is not current
function Get-LastLogEntry {
    param(
        [string]$LogFolder,
        [string]$PartName
    )

    # Validate parameters
    if (-not (Test-Path $LogFolder)) {
        Write-Error "The specified log folder does not exist: $LogFolder"
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($PartName)) {
        Write-Error "The PartName parameter cannot be empty or null."
        return
    }

    # Get log files matching the pattern
    $logFiles = Get-ChildItem -Path $LogFolder -Filter "$PartName-*.txt" -ErrorAction SilentlyContinue | Sort-Object -Property LastWriteTime -Descending

    if ($logFiles.Count -gt 0) {
        $lastLogFile = $logFiles[0].FullName
        
        try {
            # Read the full content of the file, preserving line breaks
            $logContents = Get-Content -Path $lastLogFile -Raw -ErrorAction Stop
            return $logContents
        } catch {
            Write-Error "Failed to read the log file: $lastLogFile. Error: $_"
            return
        }
    } else {
        return "No log files found."
    }
}

# Parse schedules and get Module Update schedule
$scheduledTime = Get-CheckSchedule -Schedules $Schedules -PartName $PartName

if ($Debug -eq 1) {
    Write-Host "Debug: Retrieved scheduled time: $scheduledTime"
}

# Check the type of $scheduledTime
if ($scheduledTime -is [datetime]) {
    if ($Debug -eq 1) {
        Write-Host "Debug: Type of scheduledTime: $($scheduledTime.GetType())"
        Write-Host "Debug: ScheduledTime is a valid DateTime object."
    }
} else {
    if ($Debug -eq 1) {
        Write-Host "Debug: ScheduledTime is NOT a valid DateTime object. Type is: $($scheduledTime.GetType())"
    }
    Write-Host "ScheduledTime is not a valid DateTime object."
    exit 1
}

# Check if the schedule is for today
$isToday, $daysDifference = Is-ScheduleForToday -ScheduledTime $scheduledTime

if ($isToday) {

    # let's get the ball rolling
    Write-Host "The $PartName schedule is for today. Scheduled update time: $scheduledTime. Start updates:"

} else {

    # Not today just display the logs of the previous run.
    Write-Host "The $PartName schedule is not for today. It is scheduled $daysDifference days from today."

    $Company_folder_path = $env:Company_folder_path
    if (-not $Company_folder_path) {
        Write-Warning "Environment variable 'Company_folder_path' is not set."
    }

    # update the log folder path by appending '\logs' to the base folder
    $logFolderPath = Join-Path -Path $Company_folder_path -ChildPath "logs"
    
    # Get the last log entry and display it
    $lastLog = Get-LastLogEntry -LogFolder $logFolderPath -PartName $PartName
    Write-Host "Last log entry:"
    Write-Host $lastLog
    exit 0
}