#!/usr/bin/env bash
#
# Checks for the percentage of memory free and errors if it is below the configured value
# Default is for 20% available, can be changed by passing a value to the script. EX: min=35 will set the minimum available memory to 35%
# Note: Check is only for physical memory usage and does not include swap usage

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

if [ -z "$min" ];
then
    min="20"
fi

MEM_FREE=$(free | grep Mem | awk '{print $7/$2 * 100.0}')
MEM_FREE=$(printf "%.*f\n" "0" "$MEM_FREE")

if [ $MEM_FREE -ge $min ]; 
then
	echo "$MEM_FREE% memory available. More than configured $min%"
	exit 0
else
	echo "$MEM_FREE% memory available. Less than configured $min%"
	exit 1
fi
