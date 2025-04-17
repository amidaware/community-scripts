#!/usr/bin/env python3

#old script archived & published for posterity was used with old veeam backup api v1_7.
#public

import os
import sys
import requests
import xml.etree.ElementTree as ET
from datetime import datetime

# Configuration and constants
VEEAM_API_URL = os.getenv("VEEAM_API_URL")
if not VEEAM_API_URL:
    print("Error: VEEAM_API_URL environment variable is required.")
    sys.exit(1)

DEBUG_MODE = os.getenv('DEBUG_MODE', 'false').lower() in ['true', '1', 'yes']

def debug_print(message):
    """Helper function to print debug messages."""
    if DEBUG_MODE:
        print(f"[DEBUG] {message}")

def authenticate(username, password):
    """Authenticate and get session ID using Veeam's legacy session manager endpoint."""
    debug_print("Authenticating with Veeam API.")
    auth_url = f"{VEEAM_API_URL}/sessionMngr/?v=v1_7"
    headers = {"Content-Type": "application/json"}
    
    try:
        response = requests.post(auth_url, auth=(username, password), headers=headers, verify=False)
        response.raise_for_status()
        
        # Retrieve the session ID from response headers
        session_id = response.headers['X-RestSvcSessionId']
        debug_print("Authentication successful. Session ID obtained.")
        return session_id
    except requests.exceptions.RequestException as e:
        print(f"Authentication failed: {e}")
        sys.exit(1)

def parse_restore_points(xml_content):
    """Parse XML and find the most recent restore point date per hostname."""
    root = ET.fromstring(xml_content)
    hostname_restorepoints = {}

    for ref in root.findall('.//{http://www.veeam.com/ent/v1.0}Ref'):
        # Extract the restore point date from the 'Name' attribute
        name = ref.get('Name')
        restore_date = extract_date_from_name(name)
        
        # Find hostname from backup job link within the same Ref element
        backup_link = ref.find(".//{http://www.veeam.com/ent/v1.0}Link[@Type='BackupReference']")
        if backup_link is not None:
            hostname = backup_link.get('Name')
            
            # Update latest restore date for the hostname
            if hostname not in hostname_restorepoints or restore_date > hostname_restorepoints[hostname]:
                hostname_restorepoints[hostname] = restore_date
    
    # Print the most recent restore point per hostname
    for hostname, date in hostname_restorepoints.items():
        print(f"Hostname: {hostname}, Most Recent Restore Date: {date}")

def extract_date_from_name(name):
    """Extract date from the 'Name' attribute in a specific format."""
    try:
        return datetime.strptime(name, '%b %d %Y %I:%M%p')
    except ValueError:
        debug_print(f"Failed to parse date from name '{name}'")
        return None

def fetch_restore_points(session_id):
    """Fetch raw restore points from the /restorePoints endpoint."""
    restore_points_url = f"{VEEAM_API_URL}/restorePoints"
    headers = {"X-RestSvcSessionId": session_id}
    
    try:
        response = requests.get(restore_points_url, headers=headers, verify=False)
        response.raise_for_status()
        
        # Parse and link most recent restore points to hostnames
        parse_restore_points(response.content)
        
    except requests.exceptions.RequestException as e:
        print(f"Failed to retrieve restore points: {e}")
        sys.exit(1)

def main():
    # Get username and password from environment variables
    username = os.getenv('USERNAME')
    password = os.getenv('PASSWORD')

    if not (username and password):
        print("Username (USERNAME) and password (PASSWORD) are required.")
        sys.exit(1)

    # Authenticate and get session ID
    session_id = authenticate(username, password)

    # Fetch and process restore points
    fetch_restore_points(session_id)

if __name__ == "__main__":
    # Disable SSL warnings
    requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)
    main()
