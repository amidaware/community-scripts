#!/usr/bin/env bash
#
# Checks CPU usage and errors if it is above the configured value
# Default is for 80% usage, can be changed by passing a value to the script. EX: max=95 will set the maximum CPU usage to 95%

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

if [ -z "$max" ];
then
    max="80"
fi

CPU_USAGE=$(echo "$[100-$(vmstat 1 2|tail -1|awk '{print $15}')]")

if [ $CPU_USAGE -le $max ]; 
then
	echo "CPU usage less than $max%. ($CPU_USAGE%)"
	exit 0
else
	echo "CPU usage greater than $max%. ($CPU_USAGE%)"
	exit 1
fi
