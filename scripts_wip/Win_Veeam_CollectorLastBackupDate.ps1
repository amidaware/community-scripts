$logName = "Veeam Agent"

$last_successful_backup = Get-EventLog $logName -EntryType Information, Warning -InstanceId 190 -newest 1
$last_successful_backup.TimeGenerated