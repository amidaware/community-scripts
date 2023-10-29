#!/usr/bin/env bash
# 
# With love from Stefan Lousberg 10/29/2023
#

SSH_STATUS=$(systemctl is-active sshd)

if [ "$SSH_STATUS" == "active" ]; then
    echo "SSH server (sshd) is running"
    exit 0
else
    echo "SSH server (sshd) is not running"
    exit 1
fi
