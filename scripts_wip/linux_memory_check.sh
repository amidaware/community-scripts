#!/bin/bash

# Checks for the percentage of memory free and errors if it is below the configured value. Note: Check is for both physical and swap memory usage
# Script accepts 3 env variables:
# "ok" should be passed in the script in the format: ok=30. If an env var is not set, the script will assume the threshold of 30.
# "min" should be passed in the script in the format: min=10. If an env var is not set, the script will assume the threshold of 10.
# "errormin" should be passed in the script in the format: errormin=2. If an env var is not set, the script will assume the threshold of 2.

# If free physical mem is less than min, the script will check swap.
# If swap is more than ok amount, the script gives a warning.
# If swap is less than ok amount, the script gives a warning.
# If swap is also lower than min, the script gives an error.

# Setting variables
if [ -z "$ok" ];
then
    ok=30
fi

if [ -z "$min" ];
then
    min=10
fi

if [ -z "$errormin" ];
then
    errormin=2
fi

# Get memory usage
MEMORY=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
MEMFREE=$(awk -v s="$MEMORY" 'BEGIN {printf("%d\n", 100 - int(s))}')
SWAP=$(free | grep Swap | awk '{print $3/$2 * 100.0}')
SWAPFREE=$(awk -v s="$SWAP" 'BEGIN {printf("%d\n", 100 - int(s))}')

# Show memory usage
echo "Memory usage: $MEMORY%"
echo "Swap usage: $SWAP%"
echo "Free swap: $SWAPFREE%"
echo "Free mem: $MEMFREE%"
echo -e "\n"

# Compare to configured limits
if [ $MEMFREE -ge "$min" ];
  then
    echo "$MEMFREE% memory available. More than configured $min%"
    exit 0
fi
if [ $SWAPFREE -gt "$ok" ];
  then
    echo "$MEMFREE% free physical memory less than $min%, but $SWAPFREE% free swap greater than $ok%."
    echo "Performance may be affected"
    exit 2
fi
if [ $MEMFREE -lt "$errormin" ];
  then
    echo "$MEMFREE% free physical memory less than $errormin%. This is critically low!"
    exit 1
fi
echo "Both phyical memory and swap are getting low."
echo "Free physical memory is $MEMFREE% and Free swap is $SWAPFREE%"
exit 2
