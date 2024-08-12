<#

.NOTES
    v1.2 8/2/2024 silversword411 adding is running column, fixed last run column
#>

# Get the count of tasks starting with "Tac"
$taskCount = (Get-ScheduledTask | Where-Object { $_.TaskName -like "Tac*" }).Count

# Output the total count
Write-Output "Total: $taskCount"

# Get detailed information for tasks starting with "Tac"
Get-ScheduledTask | Where-Object { $_.TaskName -like "Tac*" } | ForEach-Object {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $_.TaskName
    [PSCustomObject]@{
        TaskName     = $_.TaskName
        CreationDate = $_.Date
        LastRunTime  = $taskInfo.LastRunTime
        IsRunning    = if ($_.State -eq 'Running') { 'Yes' } else { 'No' }
    }
} | Format-Table -AutoSize