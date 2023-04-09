<#
.SYNOPSIS
    Initiates a threat scan with ESET Endpoint Antivirus

.REQUIREMENTS
    RMM feature must be enabled on the endpoints under Tools -> ESET RMM. See https://help.eset.com/ees/10/en-US/how_activate_rmm.html
    

.INSTRUCTIONS
    Configure your ESET Protect endpoint policy as follows:
      1. Enable RMM -> ON
      2. Authorization Method -> "Application Path"
      3. Application path -> C:\Program Files\TacticalAgent\tacticalrmm.exe

.PARAMETER Target
    Comma-separated list; sets the target drive(s) or path e.g. "C:\,D:\", "C:\Windows"

.PARAMETER Profile
    Sets the target profile e.g. "@Smart scan", "@In-depth scan"

.NOTES
    RMM trigger will *NOT* work unless the allowed application path is configured! OPTIONAL: You can disable authorization method, but this is DANGEROUS
    
.VERSION
    V1.0 Initial Release
#>

param(
    [string]$target = "C:\",
    [string]$profile = "@Smart scan"
)

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

$timeout = New-TimeSpan -Hours 3
$sw = [diagnostics.stopwatch]::StartNew()

Write-Host "Running eRmm.exe with target: $target and profile: $profile"
& "C:\Program Files\ESET\ESET Security\eRmm.exe" start scan --target $target -p $profile

$scanInProgress = $true

while ($scanInProgress) {
    if ($sw.elapsed -ge $timeout) {
        Write-Host "Timeout: Script exceeded 3 hours. Exiting."
        exit 1
    }
    
    Start-Sleep -Seconds 60
    $scanState = Get-ScanState

    if ($scanState -eq "finished") {
        $scanInProgress = $false
    } elseif ($scanState -eq $null) {
        Write-Host "Error: Scan state is null. Exiting."
        exit 1
    }
}

$sw.Stop()

Write-Host "Scan completed. Final results:"
$finalResults = Get-ScanInfo

if ($finalResults -eq $null) {
    Write-Host "Error: No scan information is available. Exiting."
    exit 1
}

$scan = $finalResults.result.'scan-info'.scans[0]
$scanObject = [PSCustomObject]@{
    'Scan ID'                 = $scan.scan_id
    'Timestamp'               = $scan.timestamp
    'State'                   = $scan.state
    'Start Time'              = $scan.start_time
    'Pause Time Remain'       = $scan.pause_time_remain
    'Elapsed Time (ticks)'    = $scan.elapsed_tickcount
    'Exit Code'               = $scan.exit_code
    'Total Object Count'      = $scan.total_object_count
    'Infected Object Count'   = $scan.infected_object_count
    'Cleaned Object Count'    = $scan.cleaned_object_count
    'PUA Object Count'        = $scan.pua_object_count
    'Log Timestamp'           = $scan.log_timestamp
    'Log Path'                = $scan.log_path
    'Task Type'               = $scan.task_type
    'Flags'                   = $scan.flags
}

$scanObject | Format-List
