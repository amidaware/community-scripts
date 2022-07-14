#!/bin/bash
#
# Checks for the percentage of memory free and errors if it is below the configured value
# Default is for 20% available, can be changed by passing a value to the script.
# Note: Check is only for physical memory usage and does not include swap usage

if [ -n "$1" ];
then
    VALUE=$1
else
    VALUE=20
fi

MEM_FREE=$(free | grep Mem | awk '{print $4/$2 * 100.0}')
MEM_FREE=$(printf "%.*f\n" "0" "$MEM_FREE")

if [ $MEM_FREE -ge $VALUE ]; 
then
	echo "$MEM_FREE% memory available. More than onfigured $VALUE%"
	exit 0
else
	echo "$MEM_FREE% memory available. Less than configured $VALUE%"
	exit 1
fi
