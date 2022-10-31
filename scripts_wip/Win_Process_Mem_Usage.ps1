param(
    [String] $procname,
    [Int] $warnwhenovermemsize
)

# Get-Process $procname | Select-Object name,WS

Write-Output "Warn when Memsize exceeds: $warnwhenovermemsize"

$proc_pid = (get-process $procname).Id[0]
# Write-Output "pid: $proc_pid"
# Write-Output "#####"

$Processes = get-process $procname
# Write-Output "Processes: $Processes"
# Write-Output "procname: $procname"

foreach ($Process in $Processes) {
    $Obj = New-Object psobject
    $Obj | Add-Member -MemberType NoteProperty -Name Name -Value $Process.Name
    $Obj | Add-Member -MemberType NoteProperty -Name WS -Value $Process.WS
}
# Write-Output $Process.WS

Write-Output "#####"
if ($Process.WS -gt $warnwhenovermemsize) {
    Write-Output "High mem usage of $($procname): $($Process.WS)"
    Exit 1
}
else {
    Write-Output "$($procname) below expected mem usage"
}
