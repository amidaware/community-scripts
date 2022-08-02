#!/usr/bin/env python
# Disk Space Checker by superdry

import sys
import shutil
import os
import string

exit_code = 0
available_drives = ['%s:' % d for d in string.ascii_uppercase if os.path.exists('%s:' % d)]
for path in available_drives:
    print(path)
    stat = shutil.disk_usage(path)
    #print(f"Disk usage statistics: {stat}")
    gbTotal = stat.total/float(1<<30)
    gbFree = stat.free/float(1<<30)
    gbPctFree = stat.free/stat.total
    print(f"Total: {gbTotal:.1f}GB, Free: {gbFree:.1f}GB ({gbPctFree:.0%})")
    if os.path.exists(f"{path}/DATALOSS_WARNING_README.txt"):
        print("Skipping temporary storage device")
    elif gbFree < 5 and gbPctFree < 0.1:
        print("Error:  <5GB and <10% free")
        exit_code = 2
    elif gbFree < 10 and gbPctFree < 0.1:
        print("Warning:  <10GB and <10% free")
        exit_code = max(exit_code,1)
sys.exit(exit_code)
