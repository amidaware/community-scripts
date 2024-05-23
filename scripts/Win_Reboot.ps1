<#
.SYNOPSIS
    Reboots/Restarts the computer with an optional wait time before restarting. Max wait 24hrs

.DESCRIPTION
    This script restarts the computer forcefully.

.PARAMETER Wait
    Specifies the number of seconds to wait before restarting the computer.

.EXAMPLE
    -Wait 60
    Waits for 60 seconds and then restarts the computer.

.NOTES
    v1.0 5/17/2024 Created by silversword411
#>

param(
    [int]$Wait
)

if ($Wait) {
    Sleep $Wait
    Restart-Computer -Force
}
else {
    Restart-Computer -Force
}
