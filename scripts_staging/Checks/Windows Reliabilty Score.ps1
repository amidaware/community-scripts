<#
 .SYNOPSIS
    This script gathers the average Windows Reliability Score (WRS) and checks it against a specified threshold.

.DESCRIPTION
    The script retrieves the average Windows Reliability Score from the system and compares it to the specified threshold value. 
    If the WRS is below the threshold, it outputs a message indicating the system is unreliable and exits with code 1. 
    If the WRS is above or equal to the threshold, it outputs a message indicating the system reliability is fine and exits with code 0. 
    If the threshold is set to 0, the script will skip the reliability check and exit with code 5. 
    If the average WRS cannot be calculated or is not a valid number, the script will also exit with code 5.

.PARAMETER Unreliable
    Specifies the threshold value for the reliability score. If the average WRS is below this value, the script will report the system as unreliable.

.NOTE
    Author: SAN
    Date: 01.01.24
    #public

.EXAMPLE
    -Unreliable 5
    
.CHANGELOG
    30/10/2024 SAN Changed output format

.TODO 
    Move to env var
    
#>

param (
    [string] $Unreliable = "5"
)

# Check if $Unreliable is set to 0
if ($Unreliable -eq "0") {
    Write-Output "Skipping reliability check as the threshold is set to 0."
    $host.SetShouldExit(5)
    exit 5
}

# Attempt to retrieve and calculate the average Windows Reliability Score
try {
    $wrs = (Get-CimInstance Win32_ReliabilityStabilityMetrics | Measure-Object -Average -Property SystemStabilityIndex).Average

    # Check if the retrieved WRS is a valid number
    if (-not $wrs -or $wrs -lt 0) {
        Write-Output "Error: Unable to calculate a valid Windows Reliability Score."
        $host.SetShouldExit(5)
        exit 5
    }

    # Compare WRS with the specified threshold
    if ($wrs -lt [double]$Unreliable) {
        Write-Output "WRS is unreliable with $wrs it is under $Unreliable."
        Exit 1
    } else {
        Write-Output "WRS is fine with $wrs it is over $Unreliable."
        Exit 0
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    $host.SetShouldExit(5)
    exit 5
}