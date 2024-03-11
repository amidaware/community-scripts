#!/bin/bash

# Synopsis: This script automates the process of updating software packages across multiple Linux distributions.
# It checks for the available package manager (dnf, yum, apt, pacman, or zypper) and executes the appropriate commands to update the system.
# Users can optionally allow the script to automatically reboot the system after updates by passing the --autoreboot flag.
#
# Usage:
# Update with automatic reboot --autoreboot
#
# Note: The script is designed to be flexible, catering both to interactive use cases and automated workflows.

AUTO_REBOOT=0

# Check for --autoreboot flag
for arg in "$@"; do
    if [[ $arg == "--autoreboot" ]]; then
        AUTO_REBOOT=1
    fi
done

# Update system based on package manager availability
if command -v dnf &> /dev/null; then
   dnf -y update
elif command -v yum &> /dev/null; then
   yum -y update
elif command -v apt &> /dev/null; then
   apt-get -y update && apt-get -y upgrade
elif command -v pacman &> /dev/null; then
   pacman -Syu
elif command -v zypper &> /dev/null; then
   zypper update
else
   echo "Package manager not detected. Please update your system manually."
   exit 1
fi

# Handle auto-reboot
if [ $AUTO_REBOOT -eq 1 ]; then
    echo "Rebooting in 10 seconds..."
    sleep 10 && reboot &
else
   echo "Updates done, please reboot"
fi
