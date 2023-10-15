<#
    .SYNOPSIS
    This script checks and returns the name of the active antivirus on a Windows system.
    
    .DESCRIPTION
    If Windows Defender's RealTimeProtection is disabled, the script queries for the primary active AV from SecurityCenter2 it 
    returns "No active antivirus detected." if no other Antivirus is found.

    .NOTES
    Created by: dinger1986
    Date: 15/10/23
#>

# Check if Windows Defender RealTimeProtection is enabled
$DefenderStatus = (Get-MpComputerStatus).RealTimeProtectionEnabled

if (-not $DefenderStatus) {
    # If Windows Defender's RealTimeProtection is disabled, query for the active AV from SecurityCenter2
    $ActiveAV = Get-CimInstance -Namespace Root\SecurityCenter2 -ClassName AntiVirusProduct | 
                Where-Object {$_.productState -eq 266240} | 
                Select-Object -ExpandProperty displayName -First 1

    # Check if another AV is found
    if ($ActiveAV) {
        # Output the name of the active AV
        $ActiveAV
    } else {
        "No active antivirus detected."
    }
} else {
    "Windows Defender"
}
