#!/usr/bin/env bash

# Check if zpool is installed
if ! zpool_loc="$(type -p "zpool")" || [[ -z $zpool_loc ]]; then
  echo "zpool not installed"
  exit 0
else
  #check for pools available
  zpool_list="$(zpool list)"
  if [[ "$zpool_list" == "no pools available" ]]; then
    # Check status of zpools
    echo "No pools available"
    exit 0
  else
    zpool_status="$(zpool status | grep -e DEGRADED -e OFFLINE)"
    if [[ -z "$zpool_status" ]];then
      echo "No Degraded or Offline status found."
      exit 0
    else
      echo "There were Degraded or offline status found please review the folowing output"
      zpool status
      exit 1
    fi
  fi
fi
