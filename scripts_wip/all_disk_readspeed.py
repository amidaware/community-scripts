#!/usr/bin/python3

import sys
import psutil
import time
import datetime

# v1.0 6/21/2023 ichigo1vs
# v1.1 silversword411 Set parameter to get error return when disk speed exceeds that number. Create average of 10 instead of just one read
# TODO: Add write speed options

#Obtaining initial disk information
disk_io_initial = psutil.disk_io_counters()

#0.1 second pause
time.sleep(0.1)

#Obtaining current disk information
disk_io_current = psutil.disk_io_counters()

#Calculating read throughput in MB/s
read_bytes_diff = disk_io_current.read_bytes - disk_io_initial.read_bytes
read_rate_mbytes_per_sec = round(read_bytes_diff / 1024 / 1024, 2)  # Mo/s


#Instant Output Summary
print("Disk System Activity:")
print(f"Timestamp: {datetime.datetime.now()}")
print(f"Read rate = {read_rate_mbytes_per_sec} MB/sec")

# Average 10 samples over 5 second
num_samples = 10
results = []

for i in range(num_samples):
    # Obtaining initial disk information
    disk_io_initial = psutil.disk_io_counters()

    # 0.1 second pause
    time.sleep(0.5)

    # Obtaining current disk information
    disk_io_current = psutil.disk_io_counters()

    # Calculating read throughput in MB/s
    read_bytes_diff = disk_io_current.read_bytes - disk_io_initial.read_bytes
    read_rate_mbytes_per_sec = round(read_bytes_diff / 1024 / 1024, 2)  # Mo/s
    
    # Storing each result in the list
    results.append(read_rate_mbytes_per_sec)

# Averaging the results
average_read_rate = round(sum(results) / len(results), 2)
print(f"Averaged read rate over {num_samples} samples = {average_read_rate} MB/sec")


# Checking read rate threshold
if len(sys.argv) > 1:
    try:
        max_read_rate = float(sys.argv[1])
        if average_read_rate > max_read_rate:
            print("Error: Read rate exceeds the maximum allowed.")
            sys.exit(1)
    except ValueError:
        print("No arg specified")
        sys.exit(0)