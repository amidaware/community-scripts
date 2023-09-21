#!/usr/bin/env bash

# Old code
# /usr/bin/dscl . -list /Users

# New code to list Mac users and filters out the system users
/usr/bin/dscl . -list /Users | grep -v '^_'
