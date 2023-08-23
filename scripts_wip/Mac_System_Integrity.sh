#!/bin/bash
SIPStatus=$(csrutil status | awk '{print toupper($5)}' | sed 's/\.//g')
if [ "$SIPStatus" == "ENABLED" ]; then
    echo "System Integrity: Enabled"
    systemIntegrityProtectionEnabled=1
elif [ "$SIPStatus" == "DISABLED" ]; then
    echo "System Integrity: Disabled"
    systemIntegrityProtectionEnabled=0
fi