#!/bin/bash

# This script pulls the names of all containers on the server and recreates their run commands
# https://github.com/lavie/runlike

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed."
    exit 0
fi

# Get a list of all container names
containers=$(docker ps --format "{{.Names}}")

# Iterate through the list of container names
for container in $containers
do
  # Run the docker run command for the current container
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    assaflavie/runlike $container
done
