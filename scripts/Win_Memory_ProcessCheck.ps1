<#

.SYNOPSIS
   For Setting up and running a LAPS (Local Administrator Password Solution) for non-AD
   https://www.microsoft.com/en-us/download/details.aspx?id=46899

.DESCRIPTION
   Use to monitor a process for memory leaks, set max memory size you want to check

.PARAMETER procname (required)
   To define what exe you want to monitor (don't include .exe)

.PARAMETER warnwhenovermemsize (required)
   To define what memory usage level in bytes that you want to get an error return for alerting
   
.EXAMPLE
   -procname meshagent -warnwhenovermemsize 100000000

.NOTES
   v1.0 silversword initial release
#>


param(
    [String] $procname,
    [Int] $warnwhenovermemsize
)

#####################################################################

if (!($procname)) {
    Write-Output "No procname defined, and it is required. Exiting"
    Exit 1
}

if (!($warnwhenovermemsize)) {
    Write-Output "No warnwhenovermemsize defined, and it is required. Exiting"
    Exit 1
}

#####################################################################

# Get-Process $procname | Select-Object name,WS

Write-Output "Warn when Memsize exceeds: $warnwhenovermemsize"

$proc_pid = (get-process $procname).Id[0]

$Processes = get-process $procname

foreach ($Process in $Processes) {
    $Obj = New-Object psobject
    $Obj | Add-Member -MemberType NoteProperty -Name Name -Value $Process.Name
    $Obj | Add-Member -MemberType NoteProperty -Name WS -Value $Process.WS
}
# Write-Output $Process.WS

Write-Output "#####"
if ($Process.WS -gt $warnwhenovermemsize) {
    Write-Output "WARNING: High mem usage of $($procname): $($Process.WS)"
    Exit 1
}
else {
    Write-Output "$($procname) below expected mem usage"
}
