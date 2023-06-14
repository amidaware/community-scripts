#!/bin/bash

# This script will check disk usage on Linux filesystems. It will give a warning if the usage is over the warning threshold and an error if the usage is over the error threshold
# The env variables "ERRORVALUE" and "WARNINGVALUE" should be passed in the script in the format: ERRORVALUE=xx and WARNINGVALUE=xx.
# If the env variables are not passed, the defaults of 90 75 will be applied

if [ -z "$ERRORVALUE" ];
then
    ERRORVALUE=90
fi

if [ -z "$WARNINGVALUE" ];
then
    WARNINGVALUE=75
fi

# parse disk usage percentages
ERROROUTCODE=0
WARNINGOUTCODE=0
for line in $(df -hP | egrep '^/dev/[^loop]' | awk '{ print $1 "_:_" $5 }')
do
    FILESYSTEM=$(echo "$line" | awk -F"_:_" '{ print $1 }')
    DISK_USAGE=$(echo "$line" | awk -F"_:_" '{ print $2 }' | cut -d'%' -f1 )

    if [ $DISK_USAGE -ge $ERRORVALUE ]; then
        echo -e "Error!" "$FILESYSTEM is $DISK_USAGE% used. Error threshold is $ERRORVALUE%"
        ERROROUTCODE=1
    elif [ $DISK_USAGE -ge $WARNINGVALUE ]; then
        echo -e "Warning!" "$FILESYSTEM is $DISK_USAGE% used. Warning threshold is $WARNINGVALUE%"
        WARNINGOUTCODE=1
    else
        echo "$FILESYSTEM disk usage okay at $DISK_USAGE%"
    fi
done

if [ $ERROROUTCODE -gt 0 ]; then
    echo "ERROR. One or more disks are critically low on space."
    exit 1
fi
if [ $WARNINGOUTCODE -gt 0 ]; then
    echo "WARNING. One or more disks are getting low on space."
    exit 2
else
    exit 0
fi
