<#
.Synopsis
    Checks Uptime of the computer
.DESCRIPTION
    This was written specifically for use as a "Script Check" in mind, where it the output is deliberaly light unless a warning or error condition is found that needs more investigation.

    If the totalhours of uptime of the computer is greater than or equal to the warning limit, an error is returned.
#>

[cmdletbinding()]
Param(
    [Parameter(Mandatory = $false)]
    [int]#Warn if the uptime total hours is over this limit.  Defaults to 2.5 days.
    $maximumUptimeHoursWarningLimit = 60
)

$uptime = (get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime)
    #v7 introduces Get-Uptime, but using WMI is backwards compatiable with v5

$hiberbootEnabled = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -ErrorAction Stop).HiberbootEnabled
[bool]$FastStartupEnabled = ($hiberbootEnabled -eq 1)

"CPU Uptime $([math]::Round($uptime.TotalHours,2)) hours. Fast Startup enabled: $FastStartupEnabled"

If($uptime.TotalHours -ge $maximumUptimeHoursWarningLimit){ Exit 1 }
Exit 0