<#
.SYNOPSIS
    Disk Space Check Script
    
.DESCRIPTION
    This PowerShell script checks the free disk space on local drives, excluding network drives 
    and optionally specified drives to ignore,
    and exits with different codes based on warning and error thresholds.
    
.PARAMETER warningThreshold
    The percentage of free disk space at which a warning is issued. Default is 10%.

.PARAMETER errorThreshold
    The percentage of free disk space at which an error is issued. Default is 5%.

.PARAMETER ignoreDisks
    An array of drive letters representing the disks to ignore during the disk space check.

.EXAMPLE
    -warningThreshold 15 -errorThreshold 10
    Checks disk space with custom warning (15%) and error (10%) thresholds.

    -ignoreDisks "D:", "E:"
    Checks disk space excluding drives D: and E: from the check.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    17.07.25 SAN Added debug flag, taken into account cases where all drives are ignored.


.TODO
    move flags to env 

#>

param(
    [int]$warningThreshold = 10,
    [int]$errorThreshold = 5,
    [string[]]$ignoreDisks = @(),
    [bool]$DebugOutput = $false
)

function CheckDiskSpace {
    [CmdletBinding()]
    param()

    # Get all local drives excluding network drives and the ones specified to ignore
    $allDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $drives = $allDrives | Where-Object { $_.DeviceID -notin $ignoreDisks }

    if ($drives.Count -eq 0) {
        Write-Host "OK: disks $($ignoreDisks -join ', ') are ignored"
        if ($DebugOutput) {
            Write-Host "[DEBUG] Total drives found: $($allDrives.Count)"
            Write-Host "[DEBUG] Ignored drives: $($ignoreDisks -join ', ')"
        }
        $host.SetShouldExit(0)
        return
    }

    $failedDrives = @()
    $warningDrives = @()

    foreach ($drive in $drives) {
        $freeSpacePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 2)

        if ($freeSpacePercent -lt $errorThreshold) {
            $failedDrives += $drive
        }
        elseif ($freeSpacePercent -lt $warningThreshold) {
            $warningDrives += $drive
        }
    }

    foreach ($drive in $drives) {
        $freeSpacePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 2)

        if ($failedDrives -contains $drive) {
            Write-Host "ERROR: $($drive.DeviceID) has less than $($errorThreshold)% free space ($freeSpacePercent%)."
        }
        elseif ($warningDrives -contains $drive) {
            Write-Host "WARNING: $($drive.DeviceID) has less than $($warningThreshold)% free space ($freeSpacePercent%)."
        }
        else {
            Write-Host "OK: $($drive.DeviceID) has $($freeSpacePercent)% free space."
        }
    }

    if ($DebugOutput) {
        if ($failedDrives.Count -gt 0) {
            Write-Host "DEBUG: The following drives failed:"
            $failedDrives | ForEach-Object {
                $p = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                Write-Host "DEBUG: $($_.DeviceID): $p%"
            }
        } elseif ($warningDrives.Count -gt 0) {
            Write-Host "DEBUG: The following drives are in warning:"
            $warningDrives | ForEach-Object {
                $p = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                Write-Host "DEBUG: $($_.DeviceID): $p%"
            }
        } else {
            Write-Host "DEBUG: All drives have sufficient free space."
        }
    }

    if ($failedDrives.Count -gt 0) {
        if ($DebugOutput) { Write-Host "DEBUG: exit code 2" }
        $host.SetShouldExit(2)
    }
    elseif ($warningDrives.Count -gt 0) {
        if ($DebugOutput) { Write-Host "DEBUG: exit code 1" }
        $host.SetShouldExit(1)
    }
    else {
        if ($DebugOutput) { Write-Host "DEBUG: exit code 0" }
        $host.SetShouldExit(0)
    }
}

# Execute the function
CheckDiskSpace
