#!/usr/bin/python3
import os
import re
import time
import requests
import subprocess
from fnmatch import fnmatch
from pathlib import Path


"""
.SYNOPSIS
    This script automates the process of downloading and pushing Chocolatey packages to a local Chocolatey server.
    It fetches the specified packages from the Chocolatey community repository, checks if the package version
    already exists locally to avoid duplicates, and then pushes the package to a specified local Chocolatey server.

    It is internaly dubbed "poor's man packages internalizer"

    Usage:
    - Set environment variables for the output directory, local Chocolatey server URL, API key, and base URL.
    - Define the list of package names to download in the `package_names` list.
    - Run the script, and it will download, save, and push the packages.

.EXEMPLE
    CHOCOLATEY_LOCAL_SERVER="https://XXXXXXX.XX/chocolatey"
    CHOCOLATEY_OUTDIR=E:\XXXXX
    CHOCOLATEY_API_KEY={{global.chocoapikey}}
    CHOCOLATEY_BASE_URL=https://community.chocolatey.org/api/v2/package/
    DEBUG=True

.NOTE
    Author: SAN
    Date: 01.01.24
    #public

.TODO
    Move package list out of the script
    change logic for checking existing packages against push repo rather than folder check
    3 option for each package:
        Download all versions available of tagged packages not only the latest
        keep only the latest version of tagged packages not all since start.
        as current download all version since start but not previous
    automatisation of the list package_names based on choco log requests ? (tried download -> package added to list)
    External webhook notification when update is done 
    
.CHANGELOG
    16.04.25 SAN big code cleanup & added a debug flag

"""

# List of package names to download
package_names = [
    "Chocolatey",
    "chocolatey-compatibility.extension",
    "chocolatey-core.extension",
    "chocolatey-windowsupdate.extension",
    "chocolatey.server",
    "KB2919355",
    "KB2919442",
    "KB3118401",
    "powershell-core",
    "wazuh-agent",
    "win-acme",
    "7zip",
    "7zip.install",
    "accessenum",
    "FirefoxESR",
    "notepadplusplus",
    "notepadplusplus.install",
    "vmware-tools",
    "windirstat",
    "bleachbit",
    "bleachbit.install",
    "filezilla",
    "firebird-odbc",
    "nscp",
    "syspin",
    "adobereader",
    "GoogleChrome",
    "greenshot",
    "keepass",
    "keepass.install",
    "registryworkshop",
    "teamviewer",
    "vcredist2010",
    "autohotkey",
    "autohotkey.install",
    "chocolatey.server",
    "dotnet",
    "DotNet4.6",
    "dotnet-8.0-runtime",
    "dotnet-runtime",
    "KB2999226",
    "KB3033929",
    "KB3035131",
    "vcredist140",
    "openssl",
    "vcredist2015",
    "nirlauncher",
    "sysinternals",
    "mysql",
    "icinga2"
]



# Retrieve and validate required environment variables
def get_env_var(name, default=None, required=True):
    value = os.getenv(name, default)
    if required and not value:
        print(f"Error: {name} environment variable is not set.")
        exit(1)
    return value

debug = os.getenv("DEBUG_MODE", "false").lower() == "true"
outdir = Path(get_env_var("CHOCOLATEY_OUTDIR"))
local_choco_server = get_env_var("CHOCOLATEY_LOCAL_SERVER")
api_key = get_env_var("CHOCOLATEY_API_KEY")
base_url = get_env_var("CHOCOLATEY_BASE_URL", "https://community.chocolatey.org/api/v2/package/")

if not outdir.exists():
    print(f"Output directory '{outdir}' does not exist. Exiting.")
    exit(1)

error_occurred = False

def extract_version_from_filename(filename):
    match = re.search(r"(\d+\.\d+(?:\.\d+)?)", filename)
    return match.group(1) if match else None

def package_version_exists(package_name, version, directory):
    return any(fnmatch(f.name, f"*{version}*") for f in directory.iterdir() if f.is_file())

def download_package(url):
    try:
        response = requests.get(url)
        if response.status_code == 200:
            return response
        print(f"[ERROR] Failed to download from {url} — Status: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Network error while downloading {url}: {e}")
    return None

def save_package_to_file(response, directory):
    filename = os.path.basename(response.url)
    filepath = directory / filename
    with filepath.open("wb") as f:
        f.write(response.content)
    return filepath, filename

def push_to_choco(filepath, server, api_key):
    try:
        subprocess.run(
            ["choco", "push", str(filepath), f"--source={server}", f"--api-key={api_key}", "--force"],
            check=True
        )
        print(f"[INFO] Pushed: {filepath.name}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Push failed: {e}")
        return False

def process_package(package_name):
    time.sleep(10)
    package_url = base_url + package_name

    for attempt in range(1, 4):
        response = download_package(package_url)
        if response:
            filepath, filename = save_package_to_file(response, outdir)
            version = extract_version_from_filename(filename)

            print(f"[INFO] Package '{package_name}': Filename = {filename}, Version = {version or 'Unknown'}")

            if version and package_version_exists(package_name, version, outdir):
                print(f"[INFO] Package '{package_name}' version {version} already exists. Skipping.")
                return True

            print(f"[INFO] Downloaded: {filename}")

            if push_to_choco(filepath, local_choco_server, api_key):
                return True

        if attempt < 3:
            print(f"[WARN] Retrying '{package_name}' in 1 minute... (Attempt {attempt + 1}/3)")
            time.sleep(60)

    print(f"[FAIL] Failed to process '{package_name}' after 3 attempts.")
    return False

# Main loop
for idx, package_name in enumerate(package_names):
    if not process_package(package_name):
        error_occurred = True

    if debug:
        print("[DEBUG] Dry run mode: exiting after first package.")
        break

if error_occurred:
    exit(1)