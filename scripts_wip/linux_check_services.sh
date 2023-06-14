#!/bin/bash

# Checks if one or more specified Linux services are running.
# The env variable ARRAY must be passed in the script in the format ARRAY=service1 service2 service3
# eg: ARRAY=meshagent httpd mariadb php-fpm nginx postgresql crond docker containerd

# Define an array of services to check
SERVICES=($ARRAY)

if [ -z "$SERVICES" ];
then
    echo "Please specify services in the Env Vars using the format ARRAY=service1 service2 service3"
    exit 1
fi

# Loop through the array and check the status of each service
for service in "${SERVICES[@]}"
do
  systemctl list-unit-files | grep $service.service > /dev/null 2>&1
  if [ $? -eq 1 ]
  then
    echo "$service does not exist"
  elif systemctl status $service | grep -q "Active: active"
    then
        echo "$service is running"
    else
        echo
        echo ERROR! "$service is stopped"
        exit 1
    fi
done
