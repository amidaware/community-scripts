#!/bin/bash

PlistBuddy="/usr/libexec/PlistBuddy"
IOReg="/usr/sbin/ioreg"
BatteryInfo=$("$IOReg" -ar -c AppleSmartBattery)
BatterySerialNumber=$("$PlistBuddy" -c "print 0:BatterySerialNumber" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
Serial=$("$PlistBuddy" -c "print 0:Serial" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
FirmwareSerialNumber=$("$PlistBuddy" -c "print 0:FirmwareSerialNumber" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
DesignCapacity=$("$PlistBuddy" -c "print 0:DesignCapacity" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
MaxCapacity=$("$PlistBuddy" -c "print 0:MaxCapacity" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
PermanentFailureStatus=$("$PlistBuddy" -c "print 0:PermanentFailureStatus" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
if [ "$BatterySerialNumber" == "" ] && [ "$Serial" == "" ] && [ "$FirmwareSerialNumber" == "" ]; then
    hasBatteries=0
else
    hasBatteries=1
    if [ "$PermanentFailureStatus" == "1" ]; then
        echo "Battery Failed"
        exit 0
    elif [ "$PermanentFailureStatus" == "0" ] && [ "$DesignCapacity" != "" ] && [ "$MaxCapacity" != "" ]; then
        BatteryHealthFloat=$(bc <<< "scale=2;($MaxCapacity / $DesignCapacity)*100")
        BatteryHealthStatus=$(printf "%.0f" "$BatteryHealthFloat")
        batteryHealthPercent=$((BatteryHealthStatus))
        echo Battery Health Percentage: $((BatteryHealthStatus))
    fi
fi