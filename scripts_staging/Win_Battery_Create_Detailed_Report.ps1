<#
.SYNOPSIS
   Creates a full report of the battery installed in the client machine.

.DESCRIPTION
   This script generates a battery report for the client machine and outputs it as an HTML file in the 

.OUTPUTS
   htm file located in the scripts folder of the TacticalRMM programdata folder.

.NOTES
   Author: Version: 1.0 created April 2022 by dinger1986
   V1.1 - 2023-06-06 - silversword411 - Added comments and adjusted extension
#>

If(!(test-path $env:programdata\TacticalRMM\scripts\))
{
      New-Item -ItemType Directory -Force -Path $env:programdata\TacticalRMM\scripts\
}

powercfg /batteryreport /output "$env:programdata\TacticalRMM\scripts\battery-report.htm"

get-content "$env:programdata\TacticalRMM\scripts\battery-report.htm"
