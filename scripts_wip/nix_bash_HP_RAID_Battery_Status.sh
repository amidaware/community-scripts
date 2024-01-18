#!/bin/bash
CONTROLLER=$(hpssacli ctrl all show status | grep -i battery)
echo $CONTROLLER
if [[ $CONTROLLER == *"Battery/Capacitor Status: OK"* ]]; then
  echo "RAID Battery is Healthy"
  exit 0
else
  echo "RAID Battery has Error"
  exit 2
fi