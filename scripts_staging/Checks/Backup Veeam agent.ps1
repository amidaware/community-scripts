<#
.SYNOPSIS
    This script checks the status of the Veeam Backup Agent by:
    1. Searching for the most recent `.Backup.log` file in the specified directory.
    2. Extracting the job status and completion time from the log file.
    3. Verifying whether the job was successful and if the log entry is within a specified threshold period (default is 48 hours).
    4. Outputs a simplified result

.DESCRIPTION
    The script is intended to monitor the status of Veeam backup jobs by checking the latest log 
    file in the Veeam Endpoint backup folder. 

.NOTE
    Author: SAN
    Date: 10/08/24
    #public

.CHANGELOG
    15/04/25 SAN Code Cleaup & Publication

.TODO
    Var to env
    get latest logs in case of error and output the logs

#>

$RootDirectory = "C:\ProgramData\Veeam\Endpoint"
$ThresholdHours = 48
$DateFormat = "dd.MM.yyyy HH:mm:ss"
$LogPattern = "Job session '.*' has been completed, status: '(.*?)',"

function Get-RecentLogFile {
    try {
        $logFile = Get-ChildItem -Path $RootDirectory -Filter "*.Backup.log" -Recurse | 
                   Sort-Object LastWriteTime -Descending | 
                   Select-Object -First 1
        return $logFile
    } catch {
        Write-Output "KO: Error accessing files: $_"
        exit 1
    }
}

function Get-JobStatusFromLog {
    param ($logFile)
    try {
        $recentLine = Select-String -Path $logFile.FullName -Pattern $LogPattern | 
                      Select-Object -Last 1
        
        if ($recentLine -and $recentLine.Line -match "\[(.*?)\] .* Job session '.*' has been completed, status: '(.*?)',") {
            $dateTime = $matches[1]
            $status = $matches[2]
            return @{ DateTime = $dateTime; Status = $status }
        } else {
            Write-Output "KO: No matching lines found in the log file."
            exit 1
        }
    } catch {
        Write-Output "KO: Error processing the log file: $_"
        exit 1
    }
}

function Check-JobStatus {
    param (
        [string]$dateTime,
        [string]$status
    )

    try {
        $logDate = [datetime]::ParseExact($dateTime, $DateFormat, $null)
        $timeSpan = New-TimeSpan -Start $logDate -End (Get-Date)

        if ($status -ne "Success") {
            Write-Output "KO: Job status is not 'Success'."
            exit 1
        } elseif ($timeSpan.TotalHours -gt $ThresholdHours) {
            Write-Output "KO: Log entry is older than $ThresholdHours hours."
            exit 1
        } else {
            Write-Output "OK: Job Status: $status, Date and Time: $dateTime"
            exit 0
        }
    } catch {
        Write-Output "KO: Error checking job status: $_"
        exit 1
    }
}

try {
    $logFile = Get-RecentLogFile

    if ($logFile) {
        $jobInfo = Get-JobStatusFromLog -logFile $logFile
        if ($jobInfo) {
            Check-JobStatus -dateTime $jobInfo.DateTime -status $jobInfo.Status
        }
    } else {
        Write-Output "KO: No .Backup.log files found in the directory or subdirectories."
        exit 1
    }
} catch {
    Write-Output "KO: Unexpected error: $_"
    exit 1
}
