#!/usr/bin/python3
"""
Script Name: Screenshot Capturer
Description: This script captures screenshots of the computer screen and saves them to a specified folder. 
             It can also take continuous screenshots at a specified interval. Additionally, it provides an 
             option to remove all pictures in the screenshots folder.
Notes:       Uses 19MB of disk space a minute at 1080p

Screenshots are saved in the following format:
  - File name: COMPUTERNAME_USERNAME_TIMESTAMP.png
  - Location: PROGRAMDATA/TacticalRMM/screenshots/

Usage Example:
  - Capture continuous screenshots every 5 seconds for 119 seconds:
    --dofor2

  - Remove all pictures in the screenshots folder:
    --clean
"""

import os
from datetime import datetime
import time  # Import the time module
import argparse  # Import the argparse module
import shutil  # Import the shutil module to remove files
import sys
import psutil  # Import psutil for disk space check

# Define the minimum free disk space in bytes (1GB)
MIN_FREE_DISK_SPACE = 1 * 1024 * 1024 * 1024

# Check available disk space
available_space = psutil.disk_usage(os.getenv("PROGRAMDATA")).free

# Check if available disk space is less than the minimum required
if available_space < MIN_FREE_DISK_SPACE:
    print("Aborting script: Insufficient free disk space (less than 1GB).")
    sys.exit(1)

# Try to import PIL.Image. If it fails, install Pillow using pip.
try:
    from PIL import ImageGrab
except ImportError:
    import subprocess
    import sys

    print("Pillow is not installed. Installing Pillow...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
        from PIL import ImageGrab
    except subprocess.CalledProcessError:
        print("Failed to install Pillow. Please install it manually using 'pip install Pillow'")
        sys.exit(1)

# Create an argument parser
parser = argparse.ArgumentParser(description="Take a screenshot")

# Add an optional argument to take continuous screenshots
parser.add_argument(
    "--dofor2",
    action="store_true",
    help="Take a screenshot every 5 seconds for 119 seconds",
)

# Add an optional argument to clean the screenshots folder
parser.add_argument(
    "--clean",
    action="store_true",
    help="Remove all pictures in the screenshots folder",
)

# Parse the command line arguments
args = parser.parse_args()

# If the --clean parameter is provided, remove all pictures in the screenshots folder
if args.clean:
    screenshots_folder = os.path.join(os.getenv("PROGRAMDATA"), "TacticalRMM", "screenshots")
    for filename in os.listdir(screenshots_folder):
        file_path = os.path.join(screenshots_folder, filename)
        try:
            if os.path.isfile(file_path):
                os.unlink(file_path)
        except Exception as e:
            print(f"Error deleting {file_path}: {e}")
    print(f"All cleaned")
    sys.exit(0)

# Capture the screen
screenshot = ImageGrab.grab()

# Save to file
filename = os.path.join(
    os.getenv("PROGRAMDATA"),
    "TacticalRMM",
    "screenshots",
    f"{os.environ['COMPUTERNAME']}_{os.environ['USERNAME']}_{datetime.now().strftime('%Y.%m.%d-%H.%M.%S')}.png",
)

# Ensure the screenshots directory exists
os.makedirs(os.path.dirname(filename), exist_ok=True)

# If the dofor2 parameter is provided, take additional screenshots
if args.dofor2:
    total_time = 119
    capture_interval = 5
    num_captures = total_time // capture_interval

    for i in range(num_captures):
        # Capture the screen
        screenshot = ImageGrab.grab()

        # Save to file
        filename = os.path.join(
            os.getenv("PROGRAMDATA"),
            "TacticalRMM",
            "screenshots",
            f"{os.environ['COMPUTERNAME']}_{os.environ['USERNAME']}_{datetime.now().strftime('%Y.%m.%d-%H.%M.%S')}.png",
        )

        # Ensure the screenshots directory exists
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        # Save as PNG
        screenshot.save(filename, format="PNG")

        # Wait for the next capture interval
        time.sleep(capture_interval)
    # Exit the script if --dofor2 was used
    sys.exit()


# Save as PNG
screenshot.save(filename, format="PNG")