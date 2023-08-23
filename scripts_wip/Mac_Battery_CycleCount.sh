#!/bin/bash

PlistBuddy="/usr/libexec/PlistBuddy"
IOReg="/usr/sbin/ioreg"
BatteryInfo=$("$IOReg" -ar -c AppleSmartBattery)
BatterySerialNumber=$("$PlistBuddy" -c "print 0:BatterySerialNumber" /dev/stdin 2>/dev/null <<< "$BatteryInfo") 
Serial=$("$PlistBuddy" -c "print 0:Serial" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
FirmwareSerialNumber=$("$PlistBuddy" -c "print 0:FirmwareSerialNumber" /dev/stdin 2>/dev/null <<< "$BatteryInfo")

if [ "$BatterySerialNumber" == "" ] && [ "$Serial" == "" ] && [ "$FirmwareSerialNumber" == "" ]; then
    hasBatteries=0
    echo No Battery in this system
    exit 0
else
    hasBatteries=1
    CycleCount=$("$PlistBuddy" -c "print 0:CycleCount" /dev/stdin 2>/dev/null <<< "$BatteryInfo")
    echo Cycle Count: $CycleCount
    exit 0
fi
