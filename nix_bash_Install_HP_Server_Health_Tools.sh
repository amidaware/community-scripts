#!/bin/bash
cd /tmp
wget https://downloads.linux.hpe.com/SDR/repo/mcp/centos/6/x86_64/10.40/hpssacli-2.40-13.0.x86_64.rpm
yum install -y --nogpgcheck hpssacli-2.40-13.0.x86_64.rpm
wget https://downloads.linux.hpe.com/SDR/repo/mcp/centos/6/x86_64/10.40/hp-health-10.40-1777.17.rhel6.x86_64.rpm
yum install -y --nogpgcheck hp-health-10.40-1777.17.rhel6.x86_64.rpm