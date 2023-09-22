#!/usr/bin/env bash

# Gets accurate disk usage measurements on a Mac using diskspace utility and warns if space is getting low
# Exit code of 2 when space is getting low. Exit code of 1 when space is critically low.

# https://github.com/scriptingosx/diskspace
# https://scriptingosx.com/2021/11/monterey-python-and-free-disk-space/

# Note: The ‘Available’ value matches the actually unused disk space that df and diskutil will report. The ‘Important’ value matches what Finder will report as available. The ‘Opportunistic’ value is somewhat lower, and from Apple’s documentation on the developer page, that seems to be what we should use for automated background tasks.

# Variables - Change to match your needs
lowspace=10000000000
criticalspace=5000000000

# Install diskspace utility if not already installed
if [ ! -f /usr/local/bin/diskspace ]
then
  echo "diskspace utility not found. Installing."
  curl -k -L -o /tmp/diskspace-1.pkg "https://github.com/scriptingosx/diskspace/releases/download/v1/diskspace-1.pkg"
  sudo installer -pkg /tmp/diskspace-1.pkg -target /
fi

# Check Disk space
if [[ $(/usr/local/bin/diskspace --important ) -gt $lowspace ]]; then
  echo "Disk space OK:"
  /usr/local/bin/diskspace -H
  exit 0
elif [[ $(/usr/local/bin/diskspace --important ) -gt $criticalspace ]]; then
  echo "Disk space getting low:"
  /usr/local/bin/diskspace -H
  exit 2
else
  echo "Warning: Disk space critically low:"
  /usr/local/bin/diskspace -H
  exit 1
fi
