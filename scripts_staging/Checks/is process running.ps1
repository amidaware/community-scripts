<#
.SYNOPSIS
    Checks whether a list of processes are running.

.DESCRIPTION
    This script retrieves a list of process names from the environment variable 'checkprocesslist' and checks whether 
    each process is running on the local system. If any process from the list is not running, the script will output the 
    process name and exit with a status of 1. If all processes are running, it outputs a success message.
    This script assumes that process names provided do not include file extensions (e.g., ".exe").

.EXEMPLE
    checkprocesslist=Explorer,explorer2

.NOTES
    Author: SAN
    Date: 26.09.24
    #public

#>

# Get the list of processes from the environment variable "checkprocesslist"
$processList = $env:checkprocesslist

# Ensure the environment variable is not empty
if (-not $processList) {
    Write-Output "Environment variable 'checkprocesslist' is empty or not set."
    exit 1
}

# Split the process list (assuming comma-separated values)
$processes = $processList -split ','

# Initialize a flag to track if any process is not running
$allProcessesRunning = $true

# Check each process and output its status
foreach ($process in $processes) {
    $processName = $process.Trim()

    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        Write-Output "$processName is running."
    } else {
        Write-Output "$processName is NOT running."
        $allProcessesRunning = $false
    }
}

# Exit with status 1 if any process is not running
if (-not $allProcessesRunning) {
    exit 1
}

Write-Output "All processes are running."