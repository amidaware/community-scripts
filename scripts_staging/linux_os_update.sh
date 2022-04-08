#!/bin/bash

#Update script to run for most common linux distros

if [[ `which yum` ]]; then
   yum -y update
elif [[ `which apt` ]]; then
   apt-get -y update
   apt-get -y upgrade
elif [[ `which pacman` ]]; then
   pacman -Syu
elif [[ `which zypper` ]]; then
   zypper update
else
   echo "Unknown Platform"
fi

sleep 10 && reboot &
