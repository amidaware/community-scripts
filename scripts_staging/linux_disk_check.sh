#!/bin/bash

# Checks Disk space usage on Linux

output=$(df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev' | awk '{ print $5 " " $1 }')

IFS=$'\n'
for disk in $output; do
    usep=$(echo "${disk}" | awk '{ print $1 }' | cut -d'%' -f1) 
    partition=$(echo "${disk}" | awk '{ print $2 }')
    if [ ${usep} -ge 90 ]; then
        echo "Running out of space $partition ${usep}%"
        Exit 1
    else
        echo "${partition} Disk space is fine at ${usep}%"
        exit 0
    fi
done
