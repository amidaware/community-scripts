<#
.SYNOPSIS
    A PowerShell script to check the reachability and response time of specified hosts or IP addresses using ping.

.DESCRIPTION
    This script checks if a list of hosts or IP addresses (specified in the PING_TARGETS environment variable) is reachable by sending a single ping request.
    It outputs "OK" with the latency in milliseconds if the host is reachable, or "KO" if it is not.

.PARAMETER PING_TARGETS
    Environment variable that holds a comma-separated list of IP addresses or hostnames to ping.

.PARAMETER PING_ERROR_THRESHOLD
    The threshold in milliseconds for a warning. If the ping response time exceeds this threshold, the script will output a warning and exit with code 1.

.PARAMETER PING_ERROR_THRESHOLD
    The threshold in milliseconds for an error. If the ping response time exceeds this threshold, the script will output an error and exit with code 2.

.EXEMPLE
    PING_TARGETS=8.8.8.8,1.1.1.1,example.com
    PING_ERROR_THRESHOLD=200
    PING_WARN_THRESHOLD=500

.NOTES
    Author: SAN
    Created: 08.11.24
    #public

.CHANGELOG
    13.11.24 SAN Changed from tnc to ping tnc was not trustworthy 

    
#>

# Set default threshold values (in ms)
$DefaultWarnThreshold = 300     # Default warning threshold in milliseconds
$DefaultErrorThreshold = 600    # Default error threshold in milliseconds

# Check for environment variables to override the default thresholds
$WarnThreshold = if ($env:PING_WARN_THRESHOLD) { [int]$env:PING_WARN_THRESHOLD } else { $DefaultWarnThreshold }
$ErrorThreshold = if ($env:PING_ERROR_THRESHOLD) { [int]$env:PING_ERROR_THRESHOLD } else { $DefaultErrorThreshold }

# Get the list of targets from the environment variable
$Targets = $env:PING_TARGETS -split ","   # Split comma-separated values into an array

if (-not $Targets) {
    Write-Output "No targets specified in the environment variable 'PING_TARGETS'. Exiting."
    exit 3
}

$ExitCode = 0   # Default exit code is 0 (success)

foreach ($Target in $Targets) {
    $Target = $Target.Trim()
    try {
        # Run the ping command and capture the output
        $PingResult = & ping -n 1 -w 1000 $Target 2>&1

        # Process each line in $PingResult to look for the response time
        $ResponseTime = $PingResult | Select-String -Pattern "time=(\d+)ms" | ForEach-Object {
            if ($_ -match "time=(\d+)ms") {
                [int]$matches[1]
            }
        }

        if ($ResponseTime -ne $null) {
            if ($ResponseTime -gt $ErrorThreshold) {
                Write-Output "ERR $Target $ResponseTime ms"
                $ExitCode = [math]::max($ExitCode, 2)
            } elseif ($ResponseTime -gt $WarnThreshold) {
                Write-Output "WARN $Target $ResponseTime ms"
                $ExitCode = [math]::max($ExitCode, 1)
            } else {
                Write-Output "OK $Target $ResponseTime ms"
            }
        } elseif ($PingResult -match "Request timed out") {
            Write-Output "KO $Target (Timeout)"
            $ExitCode = [math]::max($ExitCode, 3)
        } else {
            Write-Output "KO $Target (Ping command failed or unexpected output)"
            $ExitCode = [math]::max($ExitCode, 3)
        }
    }
    catch {
        Write-Output "KO $Target (Error: $_)"
        $ExitCode = [math]::max($ExitCode, 3)
    }
}

# Exit with the determined exit code (warn = 1, error = 2, fail = 3)
$host.SetShouldExit($ExitCode)
exit $ExitCode
