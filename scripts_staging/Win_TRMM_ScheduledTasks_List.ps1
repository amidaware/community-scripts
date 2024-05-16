# List TRMM Scheduled tasks. Should match info in Tasks tab of TRMM admin

(Get-ScheduledTask | Where-Object { $_.TaskName -like "Tac*" }).Count
Get-ScheduledTask -TaskName "Tac*" | Select-Object TaskName, Date | Format-table