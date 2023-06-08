<#
.SYNOPSIS
   Checks for Mesh Memory Leaks, Mesh service, folder, and .exe and returns 1 if there's a problem.

.DESCRIPTION
   This script checks for the presence of Mesh Agent service, folder, and .exe file. If any of these components are missing, it returns an error code of 1.

.PARAMETER procname
   Specifies the name of the process to monitor for memory usage.
   -procname meshagent

.PARAMETER warnwhenovermemsize
   Specifies the threshold for warning when the memory size of the process exceeds this value in bytes.
   -warnwhenovermemsize 100000000

.PARAMETER debug
   Switch parameter to enable debug output.

.NOTES
   Version: 1.0 Created 6/6/2023 by silversword411
#>

param(
    [String] $procname = "meshagent",
    [Int] $warnwhenovermemsize = 100000000,
    [switch]$debug
)

if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
}

function CheckMemorySize {
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

    Write-Debug "Warn when Memsize exceeds: $warnwhenovermemsize"
    Write-Debug "#####"

    $proc_pid = (get-process $procname).Id[0]

    $Processes = Get-WmiObject -Query "SELECT * FROM Win32_PerfFormattedData_PerfProc_Process WHERE IDProcess=$proc_pid"

    foreach ($Process in $Processes) {
        $Obj = New-Object psobject
        $Obj | Add-Member -MemberType NoteProperty -Name Name -Value $Process.Name
        $Obj | Add-Member -MemberType NoteProperty -Name WorkingSetPrivate -Value $Process.WorkingSetPrivate
    }

    $WS_MB = [math]::Round($Process.WorkingSetPrivate / 1MB, 2) 

    if ($Process.WorkingSetPrivate -gt $warnwhenovermemsize) {
        Write-Output "WARNING: $($WS_MB)MB: $($procname) has high mem usage"
        $ErrorCount += 1
    }
    else {
        Write-Output "$($WS_MB)MB: $($procname) below expected mem usage "
    }
}
CheckMemorySize

function CheckForMeshComponents {
    $serviceName = "Mesh Agent"
    $ErrorCount = 0

    if (!(Get-Service $serviceName)) { 
        Write-Output "Mesh Agent Service Missing"
        $ErrorCount += 1
    }

    else {
        Write-Output "Mesh Agent Service Found"
    }

    if (!(Test-Path "c:\Program Files\Mesh Agent")) {
        Write-Output "Mesh Agent Folder missing"
        $ErrorCount += 1
    }

    else {
        Write-Output "Mesh Agent Folder exists"
    }

    if (!(Test-Path "c:\Program Files\Mesh Agent\MeshAgent.exe")) {
        Write-Output "Mesh Agent exe missing"
        $ErrorCount += 1
    }

    else {
        Write-Output "Mesh Agent exe exists"
    }

    if (!$ErrorCount -eq 0) {
        exit 1
    }
}
CheckForMeshComponents
