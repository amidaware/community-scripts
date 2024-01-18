#!/bin/bash
CONTROLLER=$(hpssacli ctrl all show status | grep -i controller)
echo $CONTROLLER
if [[ $CONTROLLER == *"Controller Status: OK"* ]]; then
  echo "RAID Controller is Healthy"
  exit 0
else
  echo "RAID Controller has Error"
  exit 2
fi