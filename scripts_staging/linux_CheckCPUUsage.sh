#!/bin/bash
#
# Checks CPU usage and errors if it is above the configured value
# Default is for 80% usage, can be changed by passing a value to the script.

if [ -n "$1" ];
then
    VALUE=$1
else
    VALUE=80
fi

CPU_USAGE=$(echo "$[100-$(vmstat 1 2|tail -1|awk '{print $15}')]")

if [ $CPU_USAGE -le $VALUE ]; 
then
	echo "CPU usage less than $VALUE%. ($CPU_USAGE%)"
	exit 0
else
	echo "CPU usage greater than $VALUE%. ($CPU_USAGE%)"
	exit 1
fi
