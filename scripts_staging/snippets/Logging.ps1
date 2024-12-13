<#
.SYNOPSIS
    This script performs logging and log rotation for a specified part name. 
    It checks for required environment variables, creates the log folder if necessary, 
    starts logging to a timestamped log file, and registers an event to stop logging and rotate logs upon script exit.

.DESCRIPTION
    The script first checks whether the `$PartName` variable is set. If it is not, the script terminates with a warning. 
    Then, it retrieves the base folder path from the environment variable `$env:Company_folder_path`. If this environment variable is not set, the script exits with a warning.

    The script attempts to create the log folder (if it doesn't already exist) at the path derived from `$env:Company_folder_path\logs`. 
    If the folder creation fails, it exits with an error.

    The script then generates a log file name based on the part name and a timestamp. A logging session is initiated.

    A log rotation function is defined, which removes log files older than a specified number of days based on the last write time. 

    Finally, the script registers an event to stop the logging session and rotate the logs when the PowerShell session exits. 

.EXEMPLE
    $PartName = Name (set in main script)
    Company_folder_path={{global.Company_folder_path}}

.NOTES
    Author: SAN
    Date: 28.11.24
    #public

.CHANGELOG

.TODO

#>

if (-not $PartName) {
    Write-Warning "Variable 'PartName' is not set."
    exit 1
}

# Retrieve the log folder base path from the environment variable
$Company_folder_path = $env:Company_folder_path
if (-not $Company_folder_path) {
    Write-Warning "Environment variable 'Company_folder_path' is not set."
    exit 1
}

# update the log folder path by appending '\logs' to the base folder
$logFolderPath = Join-Path -Path $Company_folder_path -ChildPath "logs"

# Attempt to create the log folder if it doesn't exist
try {
    if (-not (Test-Path $logFolderPath)) {
        New-Item -Path $logFolderPath -ItemType Directory | Out-Null
        Write-Host "Log folder created at: $logFolderPath"
    }
} catch {
    Write-Warning "Failed to create log folder at: $logFolderPath. Error: $($_.Exception.Message)"
    exit 1
}

# Generate a timestamped log file name
$timestamp = (Get-Date).ToString("dd-MM-yy-HHmmss")
$logFilePath = Join-Path -Path $logFolderPath -ChildPath "$PartName-$timestamp.txt"

# Function to rotate log files
function Rotate-LogFiles {
    param(
        [string]$LogFolder,
        [string]$PartName,
        [int]$DaysOld = 200
    )

    try {
        # Calculate the cutoff date for old files
        $cutoffDate = (Get-Date).AddDays(-$DaysOld)

        # Retrieve log files matching the specified pattern
        $logFiles = Get-ChildItem -Path $LogFolder -Filter "$PartName-*.txt"

        # Select files older than the cutoff date
        $filesToRemove = $logFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }

        # Remove old log files
        foreach ($file in $filesToRemove) {
            try {
                Remove-Item -Path $file.FullName -Force -Verbose
            } catch {
                Write-Warning "Failed to remove $($file.FullName): $($_.Exception.Message)"
                exit 1
            }
        }
    } catch {
        Write-Warning "Log rotation failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

# Register event to stop logging and rotate logs on script exit
try {
    Write-Host "Registering PowerShell.Exiting event to rotate logs"
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-Host "PowerShell.Exiting event triggered: Stopping transcript and rotating logs"
        Stop-Transcript
        Rotate-LogFiles -LogFolder $using:logFolderPath -PartName $using:PartName
    }
} catch {
    Write-Warning "Failed to register PowerShell.Exiting event. Error: $($_.Exception.Message)"
    exit 1
}

# Start logging
try {
    Write-Host "Starting logging to file: $logFilePath"
    Start-Transcript -Path $logFilePath -Append

} catch {
    Write-Warning "Failed to start logging to file: $logFilePath. Error: $($_.Exception.Message)"
    exit 1
}

