<#
.SYNOPSIS
    Retrieves and logs system uptime and shutdown event information.

.DESCRIPTION
    This script retrieves the system's last boot time and calculates the uptime in days, hours, minutes, and seconds.
    It queries the Windows Event Log for the most recent shutdown-related event,
    extracts detailed shutdown metadata (including reason, process, type, and user), and optionally logs the data
    to a CSV file if the 'sendtolog' environment variable is set to '1'.

.PARAMETER sendtolog
    Environment variable used to trigger logging to a CSV file when set to "1".

.EXEMPLE
    sendtolog=1

.NOTES
    Author: SAN
    Created: 03.10.24
    Last Updated: 08.05.25
    #public

.CHANGELOG
    SAN 12.12.24 Code cleanup
    SAN 08.05.25 added detailed event property logging, added 6008 and cleanup output
    
#>


# Get system boot time and uptime
$lastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $lastBootTime
$formattedBootTime = $lastBootTime.ToString("yyyy-MM-dd HH:mm:ss")

# Try to retrieve shutdown events
try {
    $shutdownEvents = Get-WinEvent -LogName System -ErrorAction SilentlyContinue
    $filteredEvents = $shutdownEvents | Where-Object { $_.Id -eq 1074 -or $_.Id -eq 6008 }
    $shutdownEvent = $filteredEvents | Select-Object -First 1
} catch {
    Write-Output "Error fetching shutdown events: $_"
    return
}

# Output boot info
Write-Output "==========================="
Write-Output "Last Reboot Information"
Write-Output "==========================="
Write-Output "Last Boot Time                 : $formattedBootTime"
Write-Output "Uptime                         : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"

if ($shutdownEvent) {
    $eventTime = $shutdownEvent.TimeCreated
    $eventId = $shutdownEvent.Id
    $provider = $shutdownEvent.ProviderName
    $msg = $shutdownEvent.Message -replace '\r\n',' '

    Write-Output "Event Log Time                 : $eventTime"
    Write-Output "Event ID                       : $eventId"
    Write-Output "Event Source                   : $provider"
    Write-Output "Event Message                  : $msg"

    # Initialize variables for extended shutdown details
    $exe = ""; $machine = ""; $reason = ""; $code = ""; $type = ""; $info = ""; $user = ""

    if ($eventId -eq 1074) {
        $exe     = $shutdownEvent.Properties[0].Value
        $machine = $shutdownEvent.Properties[1].Value
        $reason  = $shutdownEvent.Properties[2].Value
        $code    = $shutdownEvent.Properties[3].Value
        $type    = $shutdownEvent.Properties[4].Value
        $info    = $shutdownEvent.Properties[5].Value
        $user    = $shutdownEvent.Properties[6].Value

        Write-Output "==========================="
        Write-Output "All Event Properties"
        Write-Output "==========================="
        Write-Output "Initiating Process/Executable  : $exe"
        Write-Output "Initiating Machine             : $machine"
        Write-Output "Shutdown Reason                : $reason"
        Write-Output "Shutdown Code                  : $code"
        Write-Output "Shutdown Type                  : $type"
        Write-Output "Additional Info                : $info"
        Write-Output "User Account                   : $user"
    }

    # Check environment variable for log saving
    if ($env:sendtolog -eq "1") {
        $logFolder = $env:Company_folder_path
        if (-not $logFolder) {
            Write-Output "Error: Environment variable 'Company_folder_path' is not set."
            return
        }
        if (-not (Test-Path $logFolder)) {
            Write-Output "Error: The folder path '$logFolder' does not exist."
            return
        }

        $csvPath = Join-Path $logFolder "logs/PowerCycleLog.csv"

        $logEntry = [PSCustomObject]@{
            Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            LastBootTime     = $formattedBootTime
            Uptime           = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"
            EventLogTime     = $eventTime
            EventID          = $eventId
            EventSource      = $provider
            EventMessage     = $msg
            Executable       = $exe
            Machine          = $machine
            Reason           = $reason
            Code             = $code
            Type             = $type
            Info             = $info
            User             = $user
        }

        $appendLog = $true

        if (Test-Path $csvPath) {
            $fileSizeMB = (Get-Item $csvPath).Length / 1MB
            $maxSizeMB = 10
            
            if ($fileSizeMB -gt $maxSizeMB) {
                $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
                $backupPath = Join-Path $logFolder "RebootLog_$timestamp.csv"
                Rename-Item -Path $csvPath -NewName $backupPath
                Write-Output "Log file exceeded $maxSizeMB MB. Backed up to $backupPath."
            }

            $lastEntry = Import-Csv -Path $csvPath | Select-Object -Last 1
            if ($lastEntry) {
                $propsToCompare = @("LastBootTime", "Uptime", "EventLogTime", "EventID", "EventSource", "EventMessage", "Executable", "Machine", "Reason", "Code", "Type", "Info", "User")
                $isSame = $true
                foreach ($prop in $propsToCompare) {
                    if ($logEntry.$prop -ne $lastEntry.$prop) {
                        $isSame = $false
                        break
                    }
                }
                if ($isSame) {
                    $appendLog = $false
                    Write-Output "`nLog entry already exists. Skipping append."
                }
            }
        }

        if ($appendLog) {
            if (-not (Test-Path $csvPath)) {
                $logEntry | Export-Csv -Path $csvPath -NoTypeInformation
            } else {
                $logEntry | Export-Csv -Path $csvPath -Append -NoTypeInformation
            }
            Write-Output "`nNew entry logged to: $csvPath"
        }
    }
} else {
    Write-Output "No shutdown or restart event (ID 1074/6008) found in the System log."
}
