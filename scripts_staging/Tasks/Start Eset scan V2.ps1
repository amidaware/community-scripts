<#
.SYNOPSIS
    Initiates a threat scan with ESET Endpoint Antivirus for every drive.

.DESCRIPTION
    RMM feature must be enabled on the endpoints under Tools -> ESET RMM. See https://help.eset.com/ees/10/en-US/how_activate_rmm.html
    It will scan every disk with the agent and report on any finding

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.VERSION
    Updated to scan through every drive and gather data
#>

# Function to start a scan for a given drive
function Start-EsetScan {
    param(
        [string]$driveLetter
    )
    $profile = "@In-depth scan"
    $ermmPath = "C:\Program Files\ESET\ESET Security\ermm.exe"
    & $ermmPath start scan --profile $profile --target $driveLetter
}

# Function to get scan state
function Get-ScanState {
    $scanInfoJson = & "C:\Program Files\ESET\ESET Security\eRmm.exe" get scan-info | ConvertFrom-Json
    if ($scanInfoJson.result.'scan-info'.scans -eq $null) {
        Write-Host "Error: No scans found in the output."
        return $null
    } else {
        $latestScan = $scanInfoJson.result.'scan-info'.scans | Sort-Object -Property scan_id -Descending | Select-Object -First 1
        return $latestScan.state
    }
}

# Function to get scan information
function Get-ScanInfo {
    $scanInfoJson = & "C:\Program Files\ESET\ESET Security\eRmm.exe" get scan-info | ConvertFrom-Json
    if ($scanInfoJson.result.'scan-info'.scans -eq $null) {
        Write-Host "Error: No scans found in the output."
        return $null
    } else {
        $latestScan = $scanInfoJson.result.'scan-info'.scans | Sort-Object -Property scan_id -Descending | Select-Object -First 1
        $scanInfoJson.result.'scan-info'.scans = @($latestScan)
        return $scanInfoJson
    }
}

# Get all drives
$drives = Get-PSDrive -PSProvider FileSystem

foreach ($drive in $drives) {
    # Ignore network drives
    if ($drive.Provider.Name -eq "FileSystem") {
        $driveLetter = $drive.Root
        Write-Host "Initiating scan for drive $driveLetter"
        Start-EsetScan -driveLetter $driveLetter

        $timeout = New-TimeSpan -Hours 3
        $sw = [diagnostics.stopwatch]::StartNew()

        $scanInProgress = $true

        while ($scanInProgress) {
            if ($sw.elapsed -ge $timeout) {
                Write-Host "Timeout: Script exceeded 3 hours for drive $driveLetter. Exiting."
                break
            }

            Start-Sleep -Seconds 60
            $scanState = Get-ScanState

            if ($scanState -eq "finished") {
                $scanInProgress = $false
            } elseif ($scanState -eq $null) {
                Write-Host "Error: Scan state is null for drive $driveLetter. Exiting."
                break
            }
        }

        $sw.Stop()

        Write-Host "Scan completed for drive $driveLetter. Final results:"
        $finalResults = Get-ScanInfo

        if ($finalResults -eq $null) {
            Write-Host "Error: No scan information is available for drive $driveLetter. Exiting."
            break
        }

        $scan = $finalResults.result.'scan-info'.scans[0]
        $scanObject = [PSCustomObject]@{
            'Drive'                  = $driveLetter
            'Scan ID'                = $scan.scan_id
            'Timestamp'              = $scan.timestamp
            'State'                  = $scan.state
            'Start Time'             = $scan.start_time
            'Pause Time Remain'      = $scan.pause_time_remain
            'Elapsed Time (ticks)'   = $scan.elapsed_tickcount
            'Exit Code'              = $scan.exit_code
            'Total Object Count'     = $scan.total_object_count
            'Infected Object Count'  = $scan.infected_object_count
            'Cleaned Object Count'   = $scan.cleaned_object_count
            'PUA Object Count'       = $scan.pua_object_count
            'Log Timestamp'          = $scan.log_timestamp
            'Log Path'               = $scan.log_path
            'Task Type'              = $scan.task_type
            'Flags'                  = $scan.flags
        }

        $scanObject | Format-List
    }
}