#!/usr/bin/env bash

# This script renames the mac.
# First script argument is the new name. Don't add ".local" to the name, it's done automatically.

scutil --set LocalHostName $1;
scutil --set ComputerName $1;
dscacheutil -flushcache;