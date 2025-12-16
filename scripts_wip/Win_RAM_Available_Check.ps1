<#
.Synopsis
    Checks the available amount of RAM on a computer
.DESCRIPTION
    This was written specifically for use as a "Script Check" in mind, where it the output is deliberaly light unless a warning or error condition is found that needs more investigation.

    If the total available (free) amount of RAM is less than the warning limit, an error is returned.
    
#>

[cmdletbinding()]
Param(
    [Parameter(Mandatory = $false)]
    [double]#Warn if the amount of available RAM (defaults to GB) is below this limit.  Defaults to 1 GB.
    $minimumAvailableRAM = 1,

    [Parameter(Mandatory = $false)]
    [switch]#Use percentage instead of absolute GB values
    $percent
)

$os = Get-CimInstance -ClassName Win32_OperatingSystem

$available = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
$label = "GB"
if ($Percent) {
    #Percent flag is set
    #Calculate percent of free space left on drive
    $available = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
    $label = "%"
}

If($minimumAvailableRAM -gt $available){
    Write-Output "Avalable RAM is below the threshold of $minimumAvailableRAM $label ($available $label available)."
    Exit 1
} else {
    Write-Output "Avalable RAM is above the threshold of $minimumAvailableRAM $label ($available $label available)."
    Exit 0
}