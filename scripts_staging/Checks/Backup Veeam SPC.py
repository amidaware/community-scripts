#!/usr/bin/python
"""
Synopsis:
    This script monitors the backup status of a specified VM or Computer
    by interfacing with the API of the Veeam Service Provider Console to 
    retrieve and analyze restore points.

    It checks if the latest backup is within a user-defined threshold
    and outputs a detailed restoration status report.

EXEMPLE:
    Mandatory:
        host={{agent.hostname}}
        apikey={{global.VeaamSPCapi}}
        apiurl=https://vspc.XXXXXX.XXXX:XXXX

    Optional
        THRESHOLD_HOURS=48
        force={{agent.Hostname_Override}}
        DEBUG=1
        force=DISABLEDBACKUPCHECK
NOTE:
    Author: SAN
    Date: 18.12.24
    #public

Outputs:
    - "OK" or "CRITICAL" status indicating backup health.
    - Detailed restoration status report if the backup check is successful.
    - Debug logs if DEBUG is set to True in the environment variables.
    - Disabled if DISABLEDBACKUPCHECK is set in FORCE

Changelog:

    27.03.25 SAN added more debug
    15.04.25 SAN big code cleanup + publication

TODO:
    better flow for the "force"
    set fallback to get localhostname if hosts is not specified
    avoid redundant calls to os.getenv
    more function decomposition
    graceful handling of missing keys in json responses
    use more descriptive variable names
    better error handling for missing data
    optimize vm filtering logic
    early exit for empty backed_up_vms
    
"""

import os
import sys
import json
import time
import math
import requests
from datetime import datetime, timedelta

# === Utility Functions ===
def log_debug(msg):
    """Logs debug information if debugging is enabled."""
    if env_vars['DEBUG']:
        print(msg)

def convert_size(bytes_):
    """Converts a size in bytes to a human-readable format."""
    if bytes_ == 0:
        return "0B"
    i = int(math.log(bytes_, 1024))
    return f"{round(bytes_ / (1024 ** i), 2)} {('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB')[i]}"

def expiry_days(expiry):
    """Calculates the number of days since a given expiry date."""
    expiry_date = datetime.strptime(expiry[:26], "%Y-%m-%dT%H:%M:%S.%f").date()
    return (datetime.today().date() - expiry_date).days

def get_timestamp(date_str):
    """Converts a date string to a Unix timestamp."""
    return time.mktime(datetime.strptime(date_str[:26], "%Y-%m-%dT%H:%M:%S.%f").timetuple())

def api_call_with_retries(url, method='GET', data=None, headers=None, retries=5, wait=60):
    """Makes an API call with retries for handling HTTP 429 responses."""
    for attempt in range(retries):
        try:
            res = requests.request(method, url, data=data, headers=headers)
            if res.status_code == 429 and attempt < retries - 1:
                print(f"HTTP 429 received. Retrying in {wait} seconds... (Attempt {attempt + 1}/{retries})")
                time.sleep(wait)
                continue
            res.raise_for_status()
            return res
        except requests.exceptions.RequestException as e:
            if attempt == retries - 1:
                print(f"API call failed after {retries} attempts: {e}")
                sys.exit(1)
            time.sleep(wait)

def get_auth_headers():
    """Returns the headers required for authenticated API requests."""
    return {
        "Connection": "close",
        "Authorization": f"Bearer {env_vars['APIKEY']}",
        "Content-Type": "application/json",
        "accept": "application/json",
    }

def apiGet_BackedUpVMs():
    """Retrieves a list of backed-up virtual machines."""
    url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/virtualMachines?limit=500&select=[{{'propertyPath':'name'}},{{'propertyPath':'instanceUid'}},{{'propertyPath':'backupServerUid'}}]"
    return api_call_with_retries(url, method='GET', headers=get_auth_headers())

def apiGet_VMbackups(vmUID):
    """Retrieves the list of backups for a specific VM."""
    url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/virtualMachines/{vmUID}/backups?limit=500"
    return api_call_with_retries(url, method='GET', headers=get_auth_headers())

def apiGet_BackedUpComputers():
    """Retrieves a list of computers that are backed up."""
    url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/computersManagedByBackupServer?limit=500"
    return api_call_with_retries(url, method='GET', headers=get_auth_headers())

def apiGet_ComputersRestorePoints():
    """Retrieves restore points for computers managed by the backup server."""
    url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/computersManagedByBackupServer/restorePoints?limit=500"
    return api_call_with_retries(url, method='GET', headers=get_auth_headers())

# === Environment and Constants ===
vmUID, lastRPoint, vmBkp_bkpSrvUID, tmpName, strSchedule = ("",) * 5
nameNotFound = True
isComputer = False

env_vars = {
    'HOST': None,
    'FORCE': None,
    'DEBUG': False,
    'APIKEY': None,
    'APIURL': None,
    'THRESHOLD_HOURS': 48
}
env_vars.update({k: os.getenv(k, v) for k, v in env_vars.items()})
env_vars['DEBUG'] = str(env_vars['DEBUG']).lower() in ("true", "1")

# === Exit Early Conditions ===
if not env_vars['APIKEY'] or not env_vars['APIURL']:
    print("CRITICAL: 'APIURL' and 'APIKEY' must be set.")
    sys.exit(2)

if env_vars['FORCE'] and "DISABLEDBACKUPCHECK" in env_vars['FORCE']:
    print("Backup check is disabled because 'FORCE' contains 'DISABLEDBACKUPCHECK'.")
    sys.exit(0)

def main():
    try:
        log_debug("Parsed Environment Variables:")
        log_debug(f"  HOST: {env_vars['HOST']}")
        log_debug(f"  FORCE: {env_vars['FORCE']}")
        log_debug(f"  DEBUG: {env_vars['DEBUG']}")
        api_key = env_vars['APIKEY']
        masked_api_key = f"{api_key[:3]}{'*' * (len(api_key) - 6)}{api_key[-3:]}"
        log_debug(f"  APIKEY: {masked_api_key}")
        log_debug(f"  APIURL: {env_vars['APIURL']}")
        log_debug(f"  THRESHOLD_HOURS: {env_vars['THRESHOLD_HOURS']}\n")

        log_debug("INFO: Fetching the list of all backed-up VMs...")
        response = apiGet_BackedUpVMs().json()
        backed_up_vms = response["data"]

        for vm in backed_up_vms:
            log_debug(f"VM Name: {vm['name']}")

        host_arg = (
            env_vars['FORCE']
            if env_vars.get('FORCE') and "Manual" not in env_vars['FORCE']
            else env_vars['HOST']
        )

        if env_vars.get('FORCE'):
            matching_vms = [vm for vm in backed_up_vms if host_arg == vm["name"]]
        else:
            matching_vms = [vm for vm in backed_up_vms if host_arg in vm["name"]]

        if not matching_vms and not env_vars.get('FORCE'):
            host_arg_lower = host_arg.lower()
            matching_vms = [vm for vm in backed_up_vms if host_arg_lower in vm["name"]]

        if not matching_vms:
            print(f"KO: VM or Computer '{host_arg}' not found in the backup list.")
            sys.exit(2)
        elif len(matching_vms) > 1:
            log_debug(f"WARNING: Multiple matches found for '{host_arg}':")
            for vm in matching_vms:
                log_debug(f"  - Name: {vm['name']}, VM UID: {vm['instanceUid']}")
            print("Exiting to avoid mismatches.")
            sys.exit(2)

        global vmUID, tmpName
        vmUID = matching_vms[0]["instanceUid"]
        tmpName = matching_vms[0]["name"]
        log_debug(f"INFO: Selected VM: {tmpName} (UID: {vmUID})")

        try:
            restore_points_response = (
                apiGet_ComputersRestorePoints() if isComputer else apiGet_VMbackups(vmUID)
            )
        except requests.exceptions.RequestException as e:
            print("API CALL FAILED: Unable to fetch restore points.")
            log_debug(str(e))
            sys.exit(2)

        restore_points = restore_points_response.json()["data"]

        latest_restore_point = next(
            (p['creationTimeUtc'] for p in restore_points if 'creationTimeUtc' in p),
            next((p['latestRestorePointDate'] for p in restore_points if 'latestRestorePointDate' in p), None)
        )

        if not latest_restore_point:
            print("KO: No valid restore points found.")
            sys.exit(2)

        restore_point_time = datetime.strptime(latest_restore_point[:26], "%Y-%m-%dT%H:%M:%S.%f")
        time_since_last_backup = datetime.utcnow() - restore_point_time

        threshold_hours = int(env_vars['THRESHOLD_HOURS'])
        backup_age_limit = timedelta(hours=threshold_hours)

        if time_since_last_backup <= backup_age_limit:
            print(f"OK: The latest backup was {time_since_last_backup} ago, within the threshold of {threshold_hours} hours.")
        else:
            print(f"KO: The latest backup was {time_since_last_backup} ago, exceeding the threshold of {threshold_hours} hours.")
            sys.exit(2)

        total_restore_point_size = sum(p.get('totalRestorePointSize', 0) for p in restore_points)
        total_restore_point_size_readable = convert_size(total_restore_point_size)

        print(f"Restoration Status Report:\n- VM or Computer: {tmpName}\n- Latest Restore Point Date/Time: {latest_restore_point}\n- Number of Restore Points Available: {len(restore_points)}\n- Total Size of Restore Points: {total_restore_point_size_readable}")


    except requests.exceptions.RequestException as e:
        print("KO: API call failed.")
        log_debug("API CALL FAILED: " + str(e))
        sys.exit(2)

if __name__ == "__main__":
    main()