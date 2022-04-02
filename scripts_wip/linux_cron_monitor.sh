#!/bin/bash
mv current_status_new current_status_old
cat /var/spool/cron/crontabs/* > current_status_new
diff <(cat current_status_old) <(cat current_status_new)
if [[ $? == 0 ]] ; then 
    echo "no change in cron"
else
    echo "cron changed"
    exit 1
fi