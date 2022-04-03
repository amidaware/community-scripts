#!/bin/bash

# Monitors Cron for any changes

new="/opt/cronmonitor/current_status_new"
old="/opt/cronmonitor/current_status_old"

if [[ ! -e $old ]]; then
mkdir /opt/cronmonitor/
cat /var/spool/cron/crontabs/* > $new
fi

mv $new $old
cat /var/spool/cron/crontabs/* > $new
diff <(cat $old) <(cat $new)
if [[ $? == 0 ]] ; then 
    echo "no change in cron"
else
    echo "cron changed"
    exit 1
fi
