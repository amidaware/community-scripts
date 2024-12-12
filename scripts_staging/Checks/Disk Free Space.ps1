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
    
.TODO
    Add debug flag
    move flags to env 

#>


param(
    [int]$warningThreshold = 10,
    [int]$errorThreshold = 5,
    [string[]]$ignoreDisks = @()
)

function CheckDiskSpace {
    [CmdletBinding()]
    param()

    # Get all local drives excluding network drives and the ones specified to ignore
    $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and $_.DeviceID -notin $ignoreDisks }

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
    if ($failedDrives.Count -gt 0) {
    #    Write-Host "ERROR: The following drives have less than $($errorThreshold)% free space:"
    #    $failedDrives | ForEach-Object { Write-Host "$($_.DeviceID): $([math]::Round(($_.FreeSpace / $_.Size) * 100, 2))%" }
    #    Write-Host "ERROR: exit 2"
        $host.SetShouldExit(2)
    }
    elseif ($warningDrives.Count -gt 0) {
    #    Write-Host "WARNING: The following drives have less than $($warningThreshold)% free space:"
    #    $warningDrives | ForEach-Object { Write-Host "$($_.DeviceID): $([math]::Round(($_.FreeSpace / $_.Size) * 100, 2))%" }
    #    Write-Host "Warning: exit 1"
        $host.SetShouldExit(1)
    }
    else {
    #    Write-Host "OK: All drives have sufficient free space."
        $host.SetShouldExit(0)
    }
}

# Execute the function
CheckDiskSpace