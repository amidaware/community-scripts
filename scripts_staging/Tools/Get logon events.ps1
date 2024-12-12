<#
.SYNOPSIS
    Retrieves successful user logon events in the last 24 hours,
    filtering for interactive logons and excluding system accounts.

.DESCRIPTION
    This script queries the Security event log for event ID 4624, which corresponds to successful user logons.
    It filters the results to include only logon events from the last 24 hours and focuses on interactive logons 
    (LogonType 2). The script excludes events where the username is "NT AUTHORITY\SYSTEM".

.NOTES
    Author: SAN
    Date: 19.09.24
    #public

.CHANGELOG


.TODO
    Add error handling for event log retrieval.
    Add support for additional logon types or custom filters if required.
#>

Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = 4624
    StartTime = (Get-Date).AddHours(-24)
} |
ForEach-Object { 
    $Event = [xml]$_.ToXml()
    [pscustomobject]@{
        TimeCreated = $_.TimeCreated
        Username    = $Event.Event.EventData.Data[5].'#text'
        LogonType   = $Event.Event.EventData.Data[8].'#text'
        IPAddress   = $Event.Event.EventData.Data[18].'#text'
    }
} |
Where-Object { 
    $_.Username -ne "NT AUTHORITY\SYSTEM" -and $_.LogonType -eq "2"
}