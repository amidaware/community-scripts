#!/usr/bin/python3
#public
'''
.SYNOPSIS
    Python script designed to automatically update the interface of Uptime-Kuma based online machines for Tactical.
    
.DESCRIPTION
    This script operates in two parts. The first part retrieves information from the field and the Agent ID from the Tactical Swagger
    After fetching the information, it checks whether the websites still exist in Tactical. If they don't, the script removes them from the dashboard.
    Additionally, it verifies if the sites are already present; if not, it creates them, specifying the name, URL, and Agent ID in the description.

.ADDITIONAL INFORMATIONS
    API : https://uptime-kuma-api.readthedocs.io/en/latest/index.html
    Docker-Compose : uptime-kuma on dockge
    Version : 1.5.2

.NOTE
    Author: MSA/SAN
    Date: 17.08.24

.EXEMPLE
endpoint_uptimekuma=UPTIME URL
user_uptimekuma=UPTIME USER
password_uptimekuma={{global.uptimepassword}}
rmm_key_for_uptime={{global.rmm_key_for_uptime_script}}
rmm_url=https://RMM API URL/agents
CustomFieldID=11111111

.TODO
   When a hostname is removed/moved, this script doesn't automatically delete it. Need to be fix.
   The HTTP protocol is automatically replaced by HTTPS. This should be adjusted to retain HTTP when specific keywords are used.
   Remove the URL from the display name.
''' 


# Import standard modules
import sys
import subprocess
import re
import os
import requests
import time

# Function to install missing packages
def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

# Attempt to import the 'uptime_kuma_api' module
try:
    import uptime_kuma_api
except ImportError:
    print("Module 'uptime_kuma_api' not found. Installing...")
    install("uptime_kuma_api")

# Import additional modules needed for interacting with Uptime-Kuma API
from uptime_kuma_api import UptimeKumaApi, MonitorType

# Initialise connection to the Uptime-Kuma API
api = UptimeKumaApi(os.environ.get('endpoint_uptimekuma'))
api.login(os.environ.get('user_uptimekuma'), os.environ.get('password_uptimekuma'))

# Define API key and URL from environment variables
api_key = os.getenv('rmm_key_for_uptime')
url = os.getenv('rmm_url')
custom_field_id = int(os.getenv('CustomFieldID'))

# Define headers for the API request
headers = {
    "X-API-KEY": api_key,
    "Accept": "application/json"
}

try:
    # Send a GET request to the specified URL
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        # Parse the JSON response
        data = response.json()
        
        if isinstance(data, list):
            for agent in data:
                # Check if 'custom_fields' is present in the agent data
                if 'custom_fields' in agent:
                    # Extract values from custom fields where the field ID is custom_field_id
                    filtered_values = [cf['value'] for cf in agent['custom_fields'] if cf.get('field') == custom_field_id and cf.get('value')]
                    
                    # Process agents with at least one relevant custom field
                    if filtered_values:

                        # Extract agent details
                        agent_id = agent.get('agent_id', 'N/A')
                        default_hostname = agent.get('hostname', 'N/A')
                        site_name = agent.get('site_name', 'N/A')
                        client_name = agent.get('client_name', 'N/A')
                        public_ip = agent.get('public_ip', 'N/A')
                        
                        # Get 5 first character
                        agent_id_5_char = agent_id[:5]

                        # Hostname full name
                        hostname = f"{default_hostname} [{agent_id_5_char}]"

                        # Space in order to have an output more clearly
                        print()

                        # Check and deploy client monitor
                        monitors = api.get_monitors()
                        client_monitor = next((monitor for monitor in monitors if monitor.get('name') == client_name), None)

                        if client_monitor:
                            print(f"{client_name} already exists")
                        else:
                            api.add_monitor(
                                type=MonitorType.GROUP,
                                name=client_name,
                                description="Client"
                            )
                            print(f"Client {client_name} has been created")

                        # Check and deploy site monitor under the client
                        monitors = api.get_monitors()
                        client_monitor = next((monitor for monitor in monitors if monitor.get('name') == client_name), None)

                        if any(monitor.get('name') == site_name and monitor.get('parent') == client_monitor.get('id') for monitor in monitors):
                            print(f"{site_name} already exists on {client_name}")
                        else:
                            api.add_monitor(
                                type=MonitorType.GROUP,
                                name=site_name,
                                parent=client_monitor.get('id'),
                                description="Site"
                            )
                            print(f"Site {site_name} has been created on {client_name}")

                        # Check and deploy hostname monitor under the site
                        monitors = api.get_monitors()
                        site_monitor = next((monitor for monitor in monitors if monitor.get('name') == site_name and monitor.get('parent') == client_monitor.get('id')), None)

                        if site_monitor:
                            if any(monitor.get('name') == hostname and monitor.get('parent') == site_monitor.get('id') for monitor in monitors):
                                print(f"{hostname} already exists on {client_name} / {site_name}")
                            else:
                                api.add_monitor(
                                    type=MonitorType.GROUP,
                                    name=hostname,
                                    parent=site_monitor.get('id'),
                                    description="Hostname"
                                )
                                print(f"Hostname {hostname} - {agent_id} has been created on {client_name} / {site_name}")

                        # Space in order to have an output more clearly
                        print()

                        # Add specific monitors based on filtered values
                        monitors = api.get_monitors()
                        monitor_id = None

                        # Find monitor ID for hostname
                        for monitor in monitors:
                            if monitor.get('name') == hostname:
                                monitor_id = monitor.get('id')

                        # Get relevant monitors that are children of the hostname monitor
                        relevant_monitors = [monitor for monitor in monitors if monitor.get('parent') == monitor_id]

                        for value in filtered_values:

                            # Add TCP port monitors with IP addresses
                            tcp_ports_with_ip_matches = re.findall(r'(\d+):(\d+\.\d+\.\d+\.\d+)', value)

                            for port, ip in tcp_ports_with_ip_matches:
                                if port.isdigit():
                                    port_int = int(port)
                                
                                monitor_name = f"{port_int} - {ip} [{agent_id_5_char}]"
                                
                                if any(monitor.get('name') == monitor_name for monitor in relevant_monitors):
                                    print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                else:
                                    api.add_monitor(
                                        type=MonitorType.PORT,
                                        name=monitor_name,
                                        port=port_int,
                                        interval=60,
                                        retryInterval=20,
                                        maxretries=20,
                                        parent=monitor_id,
                                        description=f"Agent ID: {agent_id}",
                                        hostname=ip
                                    )
                                    print(f"Monitoring TCP for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")

                            # Add TCP port monitors with default IP addresses
                            value = re.sub(r'\d+:\d+\.\d+\.\d+\.\d+', '', value)
                            tcp_ports_no_ip_matches = re.findall(r'\b\d{1,5}\b', value)

                            for port in tcp_ports_no_ip_matches:
                                if port.isdigit():
                                    port_int = int(port)
                                
                                monitor_name = f"{port_int} - {public_ip} [{agent_id_5_char}]"
                                
                                if any(monitor.get('name') == monitor_name for monitor in relevant_monitors):
                                    print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                else:
                                    api.add_monitor(
                                        type=MonitorType.PORT,
                                        name=monitor_name,
                                        port=port_int,
                                        interval=60,
                                        retryInterval=20,
                                        maxretries=20,
                                        parent=monitor_id,
                                        description=f"Agent ID: {agent_id}",
                                        hostname=public_ip
                                    )
                                    print(f"Monitoring TCP for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")
                            
                            # Add HTTP monitors for URLs
                            http_section_match = re.search(r'HTTP:\s*((?:(?!TCP:|KEYWORD:)[\s\S])*)', value)
                            if http_section_match:
                                http_section = http_section_match.group(1).strip()
                                http_urls = [url.strip() for url in http_section.split('\n') if url.strip()]
                                
                                for url in http_urls:
                                    original_url = url
                                    
                                    url = re.sub(r'^(https?:\/\/)+', '', url)
                                    url = re.sub(r'^\/+', '', url) 
                                    url = re.sub(r'\s+', ' ', url) 
                                    url = url.strip() 

                                    if original_url.lower().startswith('http:'):
                                        protocol = 'http://'
                                    elif original_url.lower().startswith('https:'):
                                        protocol = 'https://'
                                    else:
                                        protocol = 'https://' 

                                    full_url = f"{protocol}{url}"
                                    monitor_name = f"{full_url} [{agent_id_5_char}]"

                                    if re.match(r'^https?:\/\/[a-zA-Z0-9-._~:/?#\[\]@!$&\'()*+,;%=]+$', full_url):
                                        if any(monitor.get('name') == monitor_name for monitor in relevant_monitors):
                                            print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                        else:
                                            api.add_monitor(
                                                type=MonitorType.HTTP,
                                                name=monitor_name,
                                                url=full_url,
                                                interval=60,
                                                retryInterval=20,
                                                maxretries=20,
                                                timeout=15,
                                                expiryNotification=True,
                                                parent=monitor_id,
                                                description=f"Agent ID: {agent_id}",
                                                hostname=public_ip
                                            )
                                            print(f"Monitoring HTTP for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")
                                    else:
                                        print(f"Invalid HTTP URL: {full_url}")
                                        
                            # Add KEYWORD monitors for keyword-based URLs
                            keyword_urls_matches = re.findall(r'KEYWORD:\s*((?:[^\n]+(?:\n(?!TCP:|HTTP:))?)+)', value, re.DOTALL)
                            if keyword_urls_matches:
                                for match in keyword_urls_matches:
                                    urls = match.strip().split('\n')
                                    for url in urls:
                                        url = url.strip()
                                    
                                        if ':' in url:
                                            base_url, keyword = url.rsplit(':', 1)
                                        else:
                                            base_url = url
                                            keyword = 'test'
                                        
                                        original_protocol = ''
                                        if base_url.lower().startswith('http://'):
                                            original_protocol = 'http://'
                                        elif base_url.lower().startswith('https://'):
                                            original_protocol = 'https://'
                                        
                                        base_url = re.sub(r'^(https?:\/\/)+', '', base_url)
                                        base_url = re.sub(r'^\/+', '', base_url)
                                        base_url = re.sub(r'\s+', ' ', base_url)
                                        base_url = base_url.strip()
                                        
                                        if original_protocol:
                                            base_url = f"{original_protocol}{base_url}"
                                        elif not base_url.startswith(('http://', 'https://')):
                                            base_url = f"https://{base_url}"
                                        
                                        keyword = keyword.strip()
                                        monitor_name = f"{base_url} - {keyword} [{agent_id_5_char}]"
                                        if any(monitor.get('name') == monitor_name for monitor in relevant_monitors):
                                            print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                        else:
                                            api.add_monitor(
                                                type=MonitorType.KEYWORD,
                                                name=monitor_name,
                                                url=base_url,
                                                keyword=keyword,
                                                interval=60,
                                                retryInterval=20,
                                                maxretries=20,
                                                timeout=15,
                                                expiryNotification=True,
                                                parent=monitor_id,
                                                description=f"Agent ID: {agent_id}",
                                                hostname=public_ip
                                            )
                                            print(f"Monitoring KEYWORD for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")
                            
                            # Space in order to have an output more clearly
                            print()

                        # Reset default values
                        monitors = api.get_monitors()
                        monitor_id = None

                        # Find monitor ID for hostname
                        for monitor in monitors:
                            if monitor.get('name') == hostname:
                                monitor_id = monitor.get('id')

                        # Get relevant monitors that are children of the hostname monitor
                        relevant_monitors = [monitor for monitor in monitors if monitor.get('parent') == monitor_id]

                        # Check and remove TCP port monitors with default IP if no longer relevant
                        for monitor in relevant_monitors:
                            if monitor.get('type') == 'port':
                                monitor_name = monitor.get('name')
                                monitor_id = monitor.get('id')
                                exists_in_value = False

                                # Extract port, IP, and agent_id from monitor name
                                port_ip_match = re.match(r'(\d+) - ([\d\.]+) \[(.*?)\]', monitor_name)
                                if port_ip_match:
                                    monitor_port, monitor_ip, monitor_agent_id = port_ip_match.groups()

                                    for value in filtered_values:
                                        # Check for ports with specific IP
                                        if re.search(rf'{monitor_port}:{monitor_ip}', value):
                                            exists_in_value = True
                                            break
                                        
                                        # Check for ports with public IP
                                        if monitor_ip == public_ip:
                                            tcp_ports_no_ip = re.sub(r'\d+:\d+\.\d+\.\d+\.\d+', '', value)
                                            tcp_ports = re.findall(r'\b(\d+)\b', tcp_ports_no_ip)
                                            if monitor_port in tcp_ports:
                                                exists_in_value = True
                                                break

                                    # Check if the monitor belongs to the current agent
                                    if monitor_agent_id != agent_id_5_char:
                                        exists_in_value = True  # Don't delete monitors from other agents

                                    if not exists_in_value:
                                        print(f"{monitor_name} does not exist anymore on the agent and has been deleted on {client_name} / {site_name} / {hostname}")
                                        api.delete_monitor(monitor_id)

                        # Check and remove HTTP monitors if no longer relevant
                        for monitor in relevant_monitors:
                            if monitor.get('type') == 'http':
                                monitor_name = monitor.get('name')
                                monitor_id = monitor.get('id')
                                exists_in_value = False

                                for value in filtered_values:
                                    http_urls_matches = re.findall(r'HTTP:\s*((?:[^\n]+\n?)+)', value, re.DOTALL)
                                    if http_urls_matches:
                                        for match in http_urls_matches:
                                            urls = match.strip().split('\n')
                                            for url in urls:
                                                url = url.strip()
                                                
                                                url = re.sub(r'^(https?:\/\/)+', '', url)
                                                url = re.sub(r'^\/+', '', url)
                                                url = re.sub(r'\s+', ' ', url) 
                                                url = url.strip() 

                                                if url.lower().startswith('https:'):
                                                    protocol = 'https://'
                                                    url = url[6:]
                                                elif url.lower().startswith('http:'):
                                                    protocol = 'http://'
                                                    url = url[5:]
                                                else:
                                                    protocol = 'https://' 

                                                full_url = f"{protocol}{url}"
                                                expected_name = f"{full_url} [{agent_id_5_char}]"

                                                if monitor_name == expected_name:
                                                    exists_in_value = True
                                                    break
                                            if exists_in_value:
                                                break
                                        if exists_in_value:
                                            break
                                    if exists_in_value:
                                        break

                                if not exists_in_value:
                                    print(f"{monitor_name} does not exist anymore on the agent and has been deleted on {client_name} / {site_name} / {hostname}")
                                    api.delete_monitor(monitor_id)

                        # Check and remove KEYWORD monitors if no longer relevant
                        for monitor in relevant_monitors:
                            if monitor.get('type') == 'keyword':
                                monitor_name = monitor.get('name')
                                monitor_id = monitor.get('id')
                                exists_in_value = False

                                for value in filtered_values:
                                    keyword_urls_matches = re.findall(r'KEYWORD:\s*((?:[^\n]+\n?)+)', value, re.DOTALL)
                                    if keyword_urls_matches:
                                        for match in keyword_urls_matches:
                                            urls = match.strip().split('\n')
                                            for url in urls:
                                                url = url.strip()

                                                if ':' in url:
                                                    base_url, keyword = url.rsplit(':', 1)
                                                else:
                                                    base_url = url
                                                    keyword = 'test'

                                                base_url = re.sub(r'^(https?:\/\/)+', '', base_url)
                                                base_url = re.sub(r'^\/+', '', base_url) 
                                                base_url = re.sub(r'\s+', ' ', base_url) 
                                                base_url = base_url.strip() 

                                                if not base_url.startswith(('http://', 'https://')):
                                                    base_url = f"https://{base_url}"

                                                keyword = keyword.strip()
                                                
                                                expected_name = f"{base_url} - {keyword} [{agent_id_5_char}]"
                                                if monitor_name == expected_name:
                                                    exists_in_value = True
                                                    break
                                            if exists_in_value:
                                                break
                                        if exists_in_value:
                                            break
                                    if exists_in_value:
                                        break

                                if not exists_in_value:
                                    print(f"{monitor_name} does not exist anymore on the agent and has been deleted on {client_name} / {site_name} / {hostname}")
                                    api.delete_monitor(monitor_id)

                        # Space in order to have an output more clearly
                        print()

                        # Additional wait to ensure API is fully synced
                        time.sleep(1)


                    # Get custom fields with the field ID from the environment variable that have no value for the given agent
                    empty_values = [cf for cf in agent['custom_fields'] if cf.get('field') == custom_field_id and not cf.get('value')]

                    # Proceed only if there are custom fields that are empty
                    if empty_values:
                        # Fetch agent details with fallback defaults if values are missing
                        # Extract agent details
                        agent_id = agent.get('agent_id', 'N/A')
                        default_hostname = agent.get('hostname', 'N/A')
                        site_name = agent.get('site_name', 'N/A')
                        client_name = agent.get('client_name', 'N/A')
                        
                        # Get 5 first character
                        agent_id_5_char = agent_id[:5]

                        # Hostname full name
                        hostname = f"{default_hostname} [{agent_id_5_char}]"
                        
                        # Get the list of all relevant monitors via API
                        relevant_monitors = api.get_monitors()
                        
                        # Loop through each monitor to check for matches with the agent's hostname
                        for monitor in relevant_monitors:
                            monitor_name = monitor.get('name')
                            monitor_id = monitor.get('id')
                            monitor_child = monitor.get('childrenIDs', [])
                            
                            # If the monitor's name matches the agent's hostname, proceed
                            if monitor_name == hostname:
                                
                                # Loop through child monitors of the matched monitor
                                for child in monitor_child:
                                    # Get the name of the child monitor, with a fallback to 'Unknown' if not found
                                    child_monitor_name = api.get_monitor(child).get('name', 'Unknown')
                                    
                                    # Log a message about the child monitor being deleted
                                    print(f"{child_monitor_name} does not exist anymore on the agent and has been deleted on {client_name} / {site_name} / {hostname}")
                                    
                                    # Delete the child monitor via API
                                    api.delete_monitor(child)

                        # Additional wait to ensure API is fully synced
                        time.sleep(1)

                        # Check and remove group monitors with no children
                        NoSubMonitor = True 

                        while NoSubMonitor:
                            relevant_monitors = api.get_monitors()
                            NoSubMonitor = False

                            for monitor in relevant_monitors:
                                if monitor.get('type') == 'group':
                                    monitor_name = monitor.get('name')
                                    monitor_id = monitor.get('id')
                                    children_ids = monitor.get('childrenIDs', [])

                                    if not children_ids:
                                        print(f"{monitor_name} does not have any children")
                                        api.delete_monitor(monitor_id)
                                        NoSubMonitor = True  # Continue loop if any monitor was deleted
                            
                            # Additional wait to ensure API is fully synced
                            time.sleep(1)

            time.sleep(2)  # Sleep to avoid rapid API calls

        else:
            print("Unexpected data format received.")
        
    else:
        print(f"Request failed. Status code: {response.status_code}")
        print(f"Error message: {response.text}")

except requests.exceptions.RequestException as e:
    print(f"An error occurred during the request: {e}")

# Disconnect from the API service
api.disconnect()