<#
.SYNOPSIS
    Poor's man WSUS/SCCM part 2
    This PowerShell script is the second phase of a multi-part automation process designed to generate precise task execution dates for system maintenance. 
    It processes task schedules from the first phase, generating MONTHLY dates that are valid only for that month. 


.DESCRIPTION
    The script processes the task schedules extracted from the environment variable `SchedulesTemplate`—which was generated in the first phase—and generates exact dates and times for tasks based on specified recurrence patterns (e.g., first Monday of the month). 
    A random time offset is applied to each task’s time for additional variability.

    The script checks each task in the schedule to determine whether it should be executed or skipped:
    * Tasks marked with "SKIP" in the template will always be marked as "SKIPPED" in the output to prevent them from being processed further in the update cycle.
    * Tasks with a recurrence pattern (e.g., 1st Monday 14:30:00) will be converted into specific dates for the current month, with a randomized time added to create variability.

    The final output is a set of task schedules valid only for the current month. 
    These schedules will be used for automation and execution in the subsequent phases of the process.

    This script is agnostic to the tasks names and allow to add as much as needed in the 1st part

.EXAMPLE
    SchedulesTemplate={{agent.SchedulesTemplate}}

.NOTES
    Author: SAN // MSA
    Date: 06.08.24
    #public

.CHANGELOG
    06.08.24 SAN Initial release for generating task dates based on monthly recurrence patterns.
    12.12.24 SAN changed var names to make it clear that the template is used rather than the old current values, fixed empty values in the env var
    17.12.24 SAN fixed cases where the date contained dashes

.TODO
    Add error handling for invalid schedule formats.
    set date format in a global var and call it here to replace "MM/dd/yyyy"
    
#>

# Check if the environment variable "SchedulesTemplate" is available
if ($Env:SchedulesTemplate -eq $null -or $Env:SchedulesTemplate -match "Collected") {
    Write-Output "Template found:"
    Write-Output "$Env:SchedulesTemplate"
    exit 1
}

# Split the environment variable "SchedulesTemplate" by newline and remove the first line
$rawSchedules = $Env:SchedulesTemplate -split "`n"
$rawSchedules = $rawSchedules[1..($rawSchedules.Length - 1)]

# Function to get the date for the Nth occurrence of a specified day of the week in a given month and year
function Get-DateForNthOccurrence($year, $month, $nthOccurrence, $dayOfWeek) {
    # Create a DateTime object for the first day of the specified month and year
    $firstDayOfMonth = Get-Date -Year $year -Month $month -Day 1
    
    # Find the first occurrence of the specified day of the week in the month
    $firstOccurrenceDay = (1..7 | Where-Object { 
        ($firstDayOfMonth.AddDays($_ - 1).DayOfWeek.ToString() -eq $dayOfWeek) 
    })[0]
    
    # Calculate the date for the Nth occurrence of the day of the week
    $occurrenceDate = $firstDayOfMonth.AddDays($firstOccurrenceDay - 1 + ($nthOccurrence - 1) * 7)
    return $occurrenceDate
}

# Get the current year and month for generating monthly dates
$currentYear = (Get-Date).Year
$currentMonth = (Get-Date).Month

# Initialize an array to hold the updated schedules for this month
$updatedMonthlySchedules = @()

# Set a random number of minutes to add variability to the times
$randomMinutesOffset = Get-Random -Maximum 30

# Process each raw schedule from the first phase
foreach ($schedule in $rawSchedules) {

    # Check if the schedule indicates a task to be skipped
    if ($schedule -match "^\w+:SKIP$") {
        $updatedMonthlySchedules += ($schedule -replace "SKIP", "SKIPPED")
    }
    # Check if the schedule matches a recurrence pattern (e.g., 1st Monday 14:30:00)
    elseif ($schedule -match "(\d+)(st|nd|rd|th) (\w+) (\d{2}:\d{2}:\d{2})") {
        $nthOccurrence = [int]$matches[1]    # Extract the occurrence number (e.g., 1st, 2nd)
        $dayOfWeek = $matches[3]              # Extract the day of the week (e.g., Monday)
        $time = $matches[4]                   # Extract the time (e.g., 14:30:00)

        # Get the date for the Nth occurrence of the day of the week
        $taskDate = Get-DateForNthOccurrence -year $currentYear -month $currentMonth -nthOccurrence $nthOccurrence -dayOfWeek $dayOfWeek

        # Add random minutes to the specified time for variability
        $timeWithOffset = [datetime]::ParseExact($time, "HH:mm:ss", $null)
        $timeWithOffset = $timeWithOffset.AddMinutes($randomMinutesOffset)
        $updatedTime = $timeWithOffset.ToString("HH:mm:ss")

        # Format the date as MM/dd/yyyy
        $formattedTaskDate = $taskDate.ToString("MM/dd/yyyy").Replace('.', '/').Replace('-', '/')


        # Replace the occurrence and day of the week in the schedule with the formatted date and time
        $updatedSchedule = $schedule -replace "(\d+)(st|nd|rd|th) (\w+) \d{2}:\d{2}:\d{2}", "$formattedTaskDate $updatedTime" 

        # Add the updated schedule to the array
        $updatedMonthlySchedules += $updatedSchedule

    } else {
        # If the schedule does not match any known pattern, add it as-is
        $updatedMonthlySchedules += $schedule
    }
}

# Output the updated monthly schedules, formatted with newlines and proper spacing
$updatedMonthlySchedules -join "`n" -replace ': ', ':' | ForEach-Object { Write-Output $_ }