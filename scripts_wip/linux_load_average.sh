#!/bin/bash

# This script checks the 1 minute, 5 minute, and 15 minute load average.
# It then compares each load average value with the threshold value multiplied by the number of CPU cores and gives a warning if the threshold is exceeded.
# Eg, if the machine has 4 cores and the load average threshold is 2, the result will be 8. If any load average is higher than 8, it will give a warning and exit with an error.
# Note, the threshold is multiplied by 2 for the 1m and 1.5 for the 5m loads to avoid too many alerts

# The env variable "threshold" should be passed in the script in the format: threshold=1.0. If an env var is not set, the script will assume the threshold of 1.

if [ -z "$threshold" ]; then
    threshold=1
fi

# Get the number of CPU cores
cores=$(grep -c "^processor" /proc/cpuinfo)

# Get the load average values for 1, 5, and 15 minutes
loadavg=$(uptime | awk -F'average: ' '{print $2}')

# Extract load average values for 1, 5, and 15 minutes
loadavg_1=$(echo "$loadavg" | awk -F', ' '{print $1}')
loadavg_5=$(echo "$loadavg" | awk -F', ' '{print $2}')
loadavg_15=$(echo "$loadavg" | awk -F', ' '{print $3}')

echo "Load Average - 1 min: $loadavg_1, 5 min: $loadavg_5, 15 min: $loadavg_15"
echo "Threshold: $threshold"
echo "CPU cores: $cores"

# Calculate the acceptable range
range=$(awk 'BEGIN {print '$threshold' * '$cores'}')

# Calculate 1m range - higher to stop too many alerts
range1m=$(awk 'BEGIN {print '$threshold' * '$cores' * '2'}')

# Calculate 5m range - higher to stop too many alerts
range5m=$(awk 'BEGIN {print '$threshold' * '$cores' * '1.5'}')

# Compare load average with the threshold
if (( $(awk 'BEGIN {print ('$loadavg_15' > '$range')}') )); then
    echo "15m load average is outside the acceptable range, which is $range."
    exit 1
elif (( $(awk 'BEGIN {print ('$loadavg_5' > '$range5m')}') )); then
    echo "5m load average is outside the acceptable range, which is $range5m."
    exit 2
elif (( $(awk 'BEGIN {print ('$loadavg_1' > '$range1m')}') )); then
    echo "1m load average is outside the acceptable range, which is $range1m."
    exit 3
else
    echo "Load average is within the acceptable range, which is $range."
    exit 0
fi
