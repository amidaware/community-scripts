<#
.SYNOPSIS
    This script retrieves scheduled tasks and filters out those that match specific ignore conditions based on task folder, name, or user. It identifies rogue tasks that do not meet the ignore criteria.

.DESCRIPTION
    The script retrieves all scheduled tasks on the system and checks each task against predefined conditions to ignore certain tasks. 
    It filters tasks based on their folder path, task name, and user ID. If a task does not match any of the ignore criteria, its details (folder, name, and user) are collected. 
    The script provides a debug mode for verbose output during task processing. If rogue tasks are found, they are displayed in a table, and the script exits with a non-zero status code.


.EXAMPLE 


.NOTES
    Author: SAN
    Date: ???
    #public

.CHANGELOG
    

.TODO
    Use a flag for debug
    set ignore value from env

#>



# Set the debug flag
$debug = 0

# Retrieve all scheduled tasks
$tasks = Get-ScheduledTask

# Initialize an array to hold the task details
$taskDetails = @()

# Define ignore conditions
$ignoreFolders = @(
    "\Mozilla\",
    "\Microsoft\Office\",
    "\Microsoft\Windows\",
    "\MySQL\Installer\"
)
$ignoreNames = @(
    "Optimize Start Menu Cache",
    "DropboxUpdateTaskUserS",
    "GoogleUpdate",
    "User_Feed_Synchronization",
    "Adobe Acrobat",
    "RMM",
    "edgeupdate",
    "OneDrive Reporting Task",
    "ZoomUpdateTaskUser",
    "OneDrive Standalone Update Task"
    "CreateExplorerShellUnelevatedTask"
)
$ignoreUsers = @(
    "*svc*",
    "*Systme*",
    "*Système*",
    "*Syst*",
    "SYSTEM"
)

# Loop through each scheduled task
foreach ($task in $tasks) {
    $taskFolder = $task.TaskPath
    $taskName = $task.TaskName
    $principalUserId = $task.Principal.UserId

    # Check if triggers are null and handle accordingly
    if ($task.Triggers) {
        # Commented out because Triggers are not needed
        # $taskTriggers = $task.Triggers | ForEach-Object { $_.ToString() }
        $taskTriggers = "Triggers present"
    } else {
        $taskTriggers = "No triggers"
    }

    if ($debug -eq 1) {
        # Debug: Print the current task details
        Write-Output "Checking Task: Folder='$taskFolder', Name='$taskName', UserID='$principalUserId'"
        # Commented out because Triggers are not needed
        # Write-Output "Triggers: $($taskTriggers -join ', ')"
    }

    # Check ignore conditions
    $folderIgnored = $ignoreFolders | Where-Object { $taskFolder -like "*$_*" } | Measure-Object | Select-Object -ExpandProperty Count
    $nameIgnored = $ignoreNames | Where-Object { $taskName -like "*$_*" } | Measure-Object | Select-Object -ExpandProperty Count
    $userIgnored = $ignoreUsers | Where-Object { $principalUserId -like $_ } | Measure-Object | Select-Object -ExpandProperty Count

    if ($debug -eq 1) {
        # Debug: Print ignore conditions
        Write-Output "Folder Ignored Count: $folderIgnored"
        Write-Output "Name Ignored Count: $nameIgnored"
        Write-Output "User Ignored Count: $userIgnored"
    }

    # Determine if the task should be ignored
    $shouldIgnore = ($folderIgnored -gt 0) -or ($nameIgnored -gt 0) -or ($userIgnored -gt 0)

    if ($debug -eq 1) {
        # Debug: Print ignore decision
        Write-Output "Should Ignore: $shouldIgnore"
    }

    if (-not $shouldIgnore) {
        # Get the task registration info
        $registrationInfo = $task.RegistrationInfo

        # Add the task details to the array
        $taskDetails += [PSCustomObject]@{
            Folder = $taskFolder
            TaskName = $taskName
            RunBy = $principalUserId
            # Commented out because CreatedBy is not needed
            # CreatedBy = $registrationInfo.Author
            # Commented out because Triggers are not needed
            # Triggers = $taskTriggers -join ', '
        }
    }
}

# Check if the taskDetails array is empty
if ($taskDetails.Count -eq 0) {
    Write-Output "No rogue tasks found"
} else {
    Write-Output "Rogue tasks found, please execute with a service user"
    # Output the task details
    $taskDetails | Format-Table -AutoSize
    # Exit with status code 1
    exit 1
}