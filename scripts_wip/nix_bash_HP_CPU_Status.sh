#!/bin/bash
#Get Server/CPU status
RESULT=$(hpasmcli -s "show server" | grep -i status)
RETURN=0
#Loop through each CPU and fail if any is not OK
while IFS= read -r line; do
    echo "$line"
	if [[ $line == *"Status       : Ok"* ]]; 
	then echo "Good"; 
	else echo "Bad"; RETURN=1; 
	fi
done <<< "$RESULT"
echo $RETURN
#Return result to TRMM
if [ $RETURN == 0 ]; then
	echo "CPUs are Healthy"
	#exit 0
else 
	echo "CPU Fault"
	#exit 2
fi