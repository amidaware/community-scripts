#!/bin/bash
#
# Alerts on Tactical if there are failed services, and lists failed services

HAS_SYSTEMD=$(ps --no-headers -o comm 1)
if [ "${HAS_SYSTEMD}" != 'systemd' ]; then
    echo "This install script only supports systemd"
    echo "Please install systemd or manually create the service using your systems's service manager"
    exit 0
fi

failsvc=$(systemctl --failed | grep -v 'fwupd-refresh.service')

if [[ "$failsvc" == *"failed"* ]]; then
    echo -e 'You have failed services'
    systemctl --failed
    exit 1
else
    echo  'All services are running'
    exit 0
fi
