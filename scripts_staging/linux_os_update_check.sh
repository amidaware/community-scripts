#!/bin/bash

# Synopsis:
# This script is designed to check for available package updates on Linux systems. It supports multiple package
# managers, including apt-get (used by Debian-based distributions like Ubuntu), dnf (used by Fedora), and yum
# (used by CentOS and RHEL). The script identifies which package manager is available on the system and uses it
# to check for updates. If updates are available, it lists them and exits with code 1. If updates cannot be checked,
# it exits with code 2. If there are no updates, it exits with code 0.

# Exit Codes:
# 0 - Success: No updates are available.
# 1 - Error: Updates are available (this script treats the availability of updates as an actionable item, thus 'Error').
# 2 - Warning: The script was unable to check for updates, possibly due to an unsupported package manager or other issue.

# The script provides a straightforward way for administrators and scripts to check for software updates across a
# variety of Linux distributions using Tactical RMM, simplifying maintenance tasks and ensuring systems can be kept up to date with
# minimal manual intervention.

#!/bin/bash

# Function to check for updates using apt-get
check_apt_get() {
    apt-get update > /dev/null
    UPDATES=$(apt-get -s upgrade | awk '/^Inst/ { print $2 }')
    if [ -n "$UPDATES" ]; then
        echo "Updates available:"
        echo "$UPDATES"
        exit 1
    fi
}

# Function to check for updates using dnf
check_dnf() {
    UPDATES=$(dnf check-update | awk '{if (NR!=1) {print $1}}')
    if [ -n "$UPDATES" ]; then
        echo "Updates available:"
        echo "$UPDATES"
        exit 1
    fi
}

# Function to check for updates using yum
check_yum() {
    UPDATES=$(yum check-update | awk '{if (NR!=1 && !/Loaded plugins/) {print $1}}')
    if [ -n "$UPDATES" ]; then
        echo "Updates available:"
        echo "$UPDATES"
        exit 1
    fi
}

# Determine which package manager is available and check for updates
if command -v apt-get &> /dev/null; then
    check_apt_get
elif command -v dnf &> /dev/null; then
    check_dnf
elif command -v yum &> /dev/null; then
    check_yum
else
    echo "Unable to determine package manager or check updates."
    exit 2
fi

echo "No updates available."
exit 0
