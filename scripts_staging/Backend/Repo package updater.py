#!/usr/bin/python3
#public
import os
import requests
import subprocess
import re
import time

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

.NOTE
    Author: SAN

.TODO
    Move packages to env

"""

# List of package names to download
package_names = [
    "Chocolatey",
    "chocolatey-compatibility.extension",
    "chocolatey-core.extension",
    "chocolatey-windowsupdate.extension",
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

# Retrieve variables from environment
outdir = os.getenv("CHOCOLATEY_OUTDIR")
local_choco_server = os.getenv("CHOCOLATEY_LOCAL_SERVER")
api_key = os.getenv("CHOCOLATEY_API_KEY")
base_url = os.getenv("CHOCOLATEY_BASE_URL", "https://community.chocolatey.org/api/v2/package/")

# Check if all required environment variables are set
if not outdir:
    print("Error: CHOCOLATEY_OUTDIR environment variable is not set.")
    exit(1)
if not local_choco_server:
    print("Error: CHOCOLATEY_LOCAL_SERVER environment variable is not set.")
    exit(1)
if not api_key:
    print("Error: CHOCOLATEY_API_KEY environment variable is not set.")
    exit(1)

# Ensure the output directory exists, if not, create it
if not os.path.exists(outdir):
    print(f"Output directory '{outdir}' does not exist. Exiting.")
    exit(1)

# Variable to track if any failure occurred
error_occurred = False

# Iterate through each package name
for package_name in package_names:
    # Wait before downloading the next package
    time.sleep(10)

    # Construct the full URL for the package
    package_url = base_url + package_name

    # Retry logic for downloading the package
    for attempt in range(3):
        try:
            # Send a GET request to download the package
            response = requests.get(package_url)

            # Check if the request was successful
            if response.status_code == 200:
                # Get the default filename from the response headers
                default_filename = os.path.basename(response.url)
                filepath = os.path.join(outdir, default_filename)

                # Extract version from filename
                version_match = re.search(r"(\d+\.\d+(\.\d+)?)", default_filename)
                if version_match:
                    version = version_match.group(1)

                    # Debug: Print filename and version
                    print(f"Package '{package_name}': Filename = {default_filename}, Version = {version}")

                    # TODO: Query the local Chocolatey server to check if this package version already exists
                    # If version already exists on the server, skip downloading
                    if any(version in filename for filename in os.listdir(outdir)):
                        print(f"Package '{package_name}' with version {version} already exists in the directory. Skipping.")
                        break

                # Save the package to a file in the specified directory using the default filename
                with open(filepath, "wb") as file:
                    file.write(response.content)
                print(f"Package '{package_name}' downloaded successfully.")

                # Push the package to the local Chocolatey server
                push_command = f"choco push \"{filepath}\" --source={local_choco_server} --api-key='{api_key}' --force"
                subprocess.run(push_command, shell=True, check=True)
                print(f"Package '{package_name}' pushed to the local Chocolatey server.")
                break

            else:
                print(f"Failed to download package '{package_name}'. Status code: {response.status_code}")

        except (requests.exceptions.RequestException, subprocess.CalledProcessError) as e:
            print(f"An error occurred while processing package '{package_name}': {str(e)}")

        # Retry after 1 minute if an error occurred and this is not the final attempt
        if attempt < 2:
            print(f"Retrying download for '{package_name}' in 1 minute... (Attempt {attempt + 2}/3)")
            time.sleep(60)

    # If all 3 attempts failed, mark error_occurred as True
    else:
        print(f"Failed to process package '{package_name}' after 3 attempts.")
        error_occurred = True

# Exit with status code 1 if any error occurred
if error_occurred:
    exit(1)