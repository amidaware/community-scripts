<#
.Synopsis
    Checks Uptime of the computer
.DESCRIPTION
    This was written specifically for use as a "Script Check" in mind, where it the output is deliberaly light unless a warning or error condition is found that needs more investigation.

    If the totalhours of uptime of the computer is greater than or equal to the warning limit, an error is returned.
    
.NOTES
    Learing taken from "Win_Disk_SMART2.ps1" by nullzilla, and modified by: redanthrax
#>
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $false)]
    [int]#Warn if the uptime total hours is over this limit.  Defaults to 2.5 days.
    $maximumUptimeHoursWarningLimit = 60
)

If((Get-Uptime).TotalHours -ge $maximumUptimeHoursWarningLimit){
    return 1
    exit
}

return 0