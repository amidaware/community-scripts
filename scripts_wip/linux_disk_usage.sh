#!/bin/bash

#set value to percent threshold to monitor
VALUE=75

#parse disk usage percentages
OUTCODE=0
declare -i OUTCODE
for line in $(df -hP | egrep '^/dev/[^loop]' | awk '{ print $1 "_:_" $5 }')
  do
    FILESYSTEM=$(echo "$line" | awk -F"_:_" '{ print $1 }')
    DISK_USAGE=$(echo "$line" | awk -F"_:_" '{ print $2 }' | cut -d'%' -f1 )

    if [ $DISK_USAGE -ge $VALUE ];
    then
      echo -e "Disk Usage Alert: Needs Attention!" "A disk is using $DISK_USAGE% greater than threshold $VALUE%"
      df -hP
      OUTCODE+=1
    else
      echo "Disk usage okay."
    fi
done

if [ $OUTCODE -gt 0 ];
then 
 exit 1
else
 exit 0
fi