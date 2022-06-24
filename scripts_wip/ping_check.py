#!/usr/bin/env python
# ping checker

import subprocess
import sys

if len(sys.argv) != 2:
    print("ERROR: Missing hostname or ip argument")
    sys.exit(1)

cmd = ["ping.exe", sys.argv[1], "-n", "5"]

r = subprocess.run(cmd, capture_output=True)

success = ["Reply", "bytes", "time", "TTL"]

print(r.stdout.decode())

if all (i in r.stdout.decode() for i in success):
    sys.exit(0)

sys.exit(1)