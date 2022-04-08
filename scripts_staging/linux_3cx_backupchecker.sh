#!/usr/bin/env bash

# Checks for 3cx backups in the past 24 hours on Linux

# Use for production
#last_run=$(grep 'ManagementConsoleJS.Services.BackupService.*created' /var/lib/3cxpbx/Instance1/Data/Logs/3cxManagementConsole.log |
#   tail -n 1 |
#   cut --delimiter '|' --fields 1)

# Use static text for testing
last_run=$(echo '2022/03/30 12:13:49.028|4029|0040|Inf|[ManagementConsoleJS.Services.BackupService] Backup TestBackup3 created' |
    grep 'ManagementConsoleJS.Services.BackupService.*created' |
    tail -n 1 |
    cut --delimiter '|' --fields 1)

last_run_sec=$(date --date "${last_run}" "+%s")
now_sec=$(date --date "now" "+%s")
day_sec=$(( 60 * 60 * 24))

# Debug statements. Comment out in production.
echo "last_run_sec=${last_run_sec}"
echo "now_sec=${now_sec}"
echo "day_sec=${day_sec}"
echo "day_sec=${day_sec}"

if [[ "${day_sec}" -le "$(( now_sec - last_run_sec ))" ]]
then
    echo "last run was more than 24 hours ago"
    exit 1
else
    echo "last run was less than 24 hours ago"
    exit 0
fi
