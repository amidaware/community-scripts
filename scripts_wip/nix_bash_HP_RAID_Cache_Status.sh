#!/bin/bash
CONTROLLER=$(hpssacli ctrl all show status | grep -i cache)
echo $CONTROLLER
if [[ $CONTROLLER == *"Cache Status: OK"* ]]; then
  echo "RAID Cache is Healthy"
  exit 0
else
  echo "RAID Cache has Error"
  exit 2
fi