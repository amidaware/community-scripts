<#
.Synopsis
    Checks the battery full charge capacity VS the design capacity
.DESCRIPTION
    This was written specifically for use as a "Script Check" in mind, where it the output is deliberaly light unless a warning or error condition is found that needs more investigation.

    If the total full charge capacity is less than the minimum capacity amount, an error is returned.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
	[int]#The minimum battery full charge capacity (as a percentage of design capacity by default).  Defaults to 85 percent.
    $minimumBatteryCapacity = 85,

    [Parameter(Mandatory = $false)]
    [switch]#Set the check condition to absolute mWh values instead of a percentage
    $absoluteValues
)

try{
    $searcher = New-Object System.Management.ManagementObjectSearcher("root\wmi","SELECT * FROM BatteryStaticData")
    $batteryStatic = $searcher.Get()
        #CIM approach threw errors when Get-WMIObject did not - WMI approach is not available in PSv7, so took .NET approach
    $batteryCharge = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryFullChargedCapacity" -ErrorAction Stop
} catch {
    Write-Output "No battery detected"
	exit 0
}

if (-not $batteryStatic -or -not $batteryCharge) {
	Write-Output "No battery detected"
	exit 0
}

$chargeCapacity = $batteryCharge.FullChargedCapacity
$designCapacity = $batteryStatic.DesignedCapacity

$available = [math]::Round(($chargeCapacity / $designCapacity) * 100,2)
$label = "%"
if ($absoluteValues) {
    $available = $chargeCapacity
    $label = "mWh"
}

"Full charge capacity $available$label of $designCapacity mWh."

If($available -le $minimumBatteryCapacity){ Exit 1 }
Exit 0