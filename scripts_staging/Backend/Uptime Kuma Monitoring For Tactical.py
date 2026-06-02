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
    Version : 1.6.0

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

.CHANGELOG
    02.06.26 Big code cleanup, multiple timeouts fixes, https cleanup, value mutation bug, removed redundant calls, added startup check, modularisation
.TODO
   When a hostname is removed/moved, this script doesn't automatically delete it. Need to be fix.
   The HTTP protocol is automatically replaced by HTTPS. This should be adjusted to retain HTTP when specific keywords are used.
   Remove the URL from the display name.

''' 


import sys
import subprocess
import re
import os
import requests
import time
import socketio


def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])


try:
    import uptime_kuma_api
except ImportError:
    print("Module 'uptime_kuma_api' not found. Installing...")
    install("uptime_kuma_api")

from uptime_kuma_api import UptimeKumaApi, MonitorType


def safe_api_call(fn, *args, retries=3, delay=2, **kwargs):
    for attempt in range(retries):
        try:
            return fn(*args, **kwargs)
        except socketio.exceptions.TimeoutError:
            if attempt == retries - 1:
                print(f"TimeoutError after {retries} retries")
                return None
            print(f"Timeout, retrying ({attempt + 1}/{retries})...")
            time.sleep(delay)
        except Exception as e:
            if attempt == retries - 1:
                print(f"Error after {retries} retries: {e}")
                return None
            print(f"Error (attempt {attempt + 1}/{retries}): {e}")
            time.sleep(delay)


def normalize_url(raw_url):
    url = re.sub(r'^(https?:\/\/)+', '', raw_url)
    url = re.sub(r'^\/+', '', url)
    url = re.sub(r'\s+', ' ', url)
    url = url.strip()
    if raw_url.lower().startswith('http:'):
        protocol = 'http://'
    elif raw_url.lower().startswith('https:'):
        protocol = 'https://'
    else:
        protocol = 'https://'
    return f"{protocol}{url}"


def get_hostname_monitor_id(monitors, hostname):
    for monitor in monitors:
        if monitor.get('name') == hostname:
            return monitor.get('id')
    return None


def validate_env_vars():
    required = [
        'endpoint_uptimekuma', 'user_uptimekuma', 'password_uptimekuma',
        'rmm_key_for_uptime', 'rmm_url', 'CustomFieldID'
    ]
    missing = [v for v in required if not os.environ.get(v)]
    if missing:
        print(f"Missing required environment variables: {', '.join(missing)}")
        sys.exit(1)


if __name__ == '__main__':
    validate_env_vars()

    endpoint = os.environ.get('endpoint_uptimekuma')
    user = os.environ.get('user_uptimekuma')
    password = os.environ.get('password_uptimekuma')

    api = UptimeKumaApi(endpoint)
    api.timeout = 30
    safe_api_call(api.login, user, password)

    api_key = os.getenv('rmm_key_for_uptime')
    url = os.getenv('rmm_url')
    custom_field_id = int(os.getenv('CustomFieldID'))

    headers = {
        "X-API-KEY": api_key,
        "Accept": "application/json"
    }

    try:
        response = requests.get(url, headers=headers)

        if response.status_code == 200:
            data = response.json()

            if isinstance(data, list):
                for agent in data:
                    if 'custom_fields' in agent:
                        filtered_values = [
                            cf['value'] for cf in agent['custom_fields']
                            if cf.get('field') == custom_field_id and cf.get('value')
                        ]

                        if filtered_values:
                            agent_id = agent.get('agent_id', 'N/A')
                            default_hostname = agent.get('hostname', 'N/A')
                            site_name = agent.get('site_name', 'N/A')
                            client_name = agent.get('client_name', 'N/A')
                            public_ip = agent.get('public_ip', 'N/A')

                            agent_id_5_char = agent_id[:5]
                            hostname = f"{default_hostname} [{agent_id_5_char}]"

                            print()

                            monitors = api.get_monitors()

                            client_monitor = next(
                                (m for m in monitors if m.get('name') == client_name), None
                            )

                            if client_monitor:
                                print(f"{client_name} already exists")
                            else:
                                safe_api_call(
                                    api.add_monitor,
                                    type=MonitorType.GROUP,
                                    name=client_name,
                                    description="Client"
                                )
                                print(f"Client {client_name} has been created")
                                monitors = api.get_monitors()
                                client_monitor = next(
                                    (m for m in monitors if m.get('name') == client_name), None
                                )

                            if any(
                                m.get('name') == site_name and m.get('parent') == client_monitor.get('id')
                                for m in monitors
                            ):
                                print(f"{site_name} already exists on {client_name}")
                            else:
                                safe_api_call(
                                    api.add_monitor,
                                    type=MonitorType.GROUP,
                                    name=site_name,
                                    parent=client_monitor.get('id'),
                                    description="Site"
                                )
                                print(f"Site {site_name} has been created on {client_name}")

                            monitors = api.get_monitors()
                            site_monitor = next(
                                (m for m in monitors
                                 if m.get('name') == site_name and m.get('parent') == client_monitor.get('id')),
                                None
                            )

                            if site_monitor:
                                if any(
                                    m.get('name') == hostname and m.get('parent') == site_monitor.get('id')
                                    for m in monitors
                                ):
                                    print(f"{hostname} already exists on {client_name} / {site_name}")
                                else:
                                    safe_api_call(
                                        api.add_monitor,
                                        type=MonitorType.GROUP,
                                        name=hostname,
                                        parent=site_monitor.get('id'),
                                        description="Hostname"
                                    )
                                    print(f"Hostname {hostname} - {agent_id} has been created on {client_name} / {site_name}")

                            print()

                            monitors = api.get_monitors()
                            hostname_monitor_id = get_hostname_monitor_id(monitors, hostname)
                            relevant_monitors = [
                                m for m in monitors if m.get('parent') == hostname_monitor_id
                            ]

                            for value in filtered_values:
                                tcp_ports_with_ip_matches = re.findall(r'(\d+):(\d+\.\d+\.\d+\.\d+)', value)

                                for port, ip in tcp_ports_with_ip_matches:
                                    port_int = int(port)
                                    monitor_name = f"{port_int} - {ip} [{agent_id_5_char}]"

                                    if any(m.get('name') == monitor_name for m in relevant_monitors):
                                        print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                    else:
                                        safe_api_call(
                                            api.add_monitor,
                                            type=MonitorType.PORT,
                                            name=monitor_name,
                                            port=port_int,
                                            interval=60,
                                            retryInterval=20,
                                            maxretries=20,
                                            parent=hostname_monitor_id,
                                            description=f"Agent ID: {agent_id}",
                                            hostname=ip
                                        )
                                        print(f"Monitoring TCP for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")

                                cleaned_value = re.sub(r'\d+:\d+\.\d+\.\d+\.\d+', '', value)
                                tcp_ports_no_ip_matches = re.findall(r'\b\d{1,5}\b', cleaned_value)

                                for port in tcp_ports_no_ip_matches:
                                    port_int = int(port)
                                    monitor_name = f"{port_int} - {public_ip} [{agent_id_5_char}]"

                                    if any(m.get('name') == monitor_name for m in relevant_monitors):
                                        print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                    else:
                                        safe_api_call(
                                            api.add_monitor,
                                            type=MonitorType.PORT,
                                            name=monitor_name,
                                            port=port_int,
                                            interval=60,
                                            retryInterval=20,
                                            maxretries=20,
                                            parent=hostname_monitor_id,
                                            description=f"Agent ID: {agent_id}",
                                            hostname=public_ip
                                        )
                                        print(f"Monitoring TCP for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")

                                http_section_match = re.search(
                                    r'HTTP:\s*((?:(?!TCP:|KEYWORD:)[\s\S])*)', value
                                )
                                if http_section_match:
                                    http_section = http_section_match.group(1).strip()
                                    http_urls = [u.strip() for u in http_section.split('\n') if u.strip()]

                                    for raw_url in http_urls:
                                        full_url = normalize_url(raw_url)
                                        monitor_name = f"{full_url} [{agent_id_5_char}]"

                                        if re.match(r'^https?:\/\/[a-zA-Z0-9-._~:/?#\[\]@!$&\'()*+,;%=]+$', full_url):
                                            if any(m.get('name') == monitor_name for m in relevant_monitors):
                                                print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                            else:
                                                safe_api_call(
                                                    api.add_monitor,
                                                    type=MonitorType.HTTP,
                                                    name=monitor_name,
                                                    url=full_url,
                                                    interval=60,
                                                    retryInterval=20,
                                                    maxretries=20,
                                                    timeout=15,
                                                    expiryNotification=True,
                                                    parent=hostname_monitor_id,
                                                    description=f"Agent ID: {agent_id}",
                                                    hostname=public_ip
                                                )
                                                print(f"Monitoring HTTP for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")
                                        else:
                                            print(f"Invalid HTTP URL: {full_url}")

                                keyword_urls_matches = re.findall(
                                    r'KEYWORD:\s*((?:[^\n]+(?:\n(?!TCP:|HTTP:))?)+)', value, re.DOTALL
                                )
                                if keyword_urls_matches:
                                    for match in keyword_urls_matches:
                                        urls = match.strip().split('\n')
                                        for entry in urls:
                                            entry = entry.strip()
                                            if ':' in entry:
                                                base_url_raw, keyword = entry.rsplit(':', 1)
                                            else:
                                                base_url_raw = entry
                                                keyword = 'test'

                                            full_url = normalize_url(base_url_raw)
                                            keyword = keyword.strip()
                                            monitor_name = f"{full_url} - {keyword} [{agent_id_5_char}]"

                                            if any(m.get('name') == monitor_name for m in relevant_monitors):
                                                print(f"{monitor_name} already exists on {client_name} / {site_name} / {hostname}")
                                            else:
                                                safe_api_call(
                                                    api.add_monitor,
                                                    type=MonitorType.KEYWORD,
                                                    name=monitor_name,
                                                    url=full_url,
                                                    keyword=keyword,
                                                    interval=60,
                                                    retryInterval=20,
                                                    maxretries=20,
                                                    timeout=15,
                                                    expiryNotification=True,
                                                    parent=hostname_monitor_id,
                                                    description=f"Agent ID: {agent_id}",
                                                    hostname=public_ip
                                                )
                                                print(f"Monitoring KEYWORD for {monitor_name} has been created on {client_name} / {site_name} / {hostname}")

                            print()

                            monitors = api.get_monitors()
                            hostname_monitor_id = get_hostname_monitor_id(monitors, hostname)
                            relevant_monitors = [
                                m for m in monitors if m.get('parent') == hostname_monitor_id
                            ]

                            for monitor in relevant_monitors:
                                if monitor.get('type') == 'port':
                                    monitor_name = monitor.get('name')
                                    child_monitor_id = monitor.get('id')
                                    exists_in_value = False

                                    port_ip_match = re.match(
                                        r'(\d+) - ([\d\.]+) \[(.*?)\]', monitor_name
                                    )
                                    if port_ip_match:
                                        monitor_port, monitor_ip, monitor_agent_id = port_ip_match.groups()

                                        for value in filtered_values:
                                            if re.search(rf'{monitor_port}:{monitor_ip}', value):
                                                exists_in_value = True
                                                break

                                            if monitor_ip == public_ip:
                                                cleaned = re.sub(
                                                    r'\d+:\d+\.\d+\.\d+\.\d+', '', value
                                                )
                                                tcp_ports = re.findall(r'\b(\d+)\b', cleaned)
                                                if monitor_port in tcp_ports:
                                                    exists_in_value = True
                                                    break

                                        if monitor_agent_id != agent_id_5_char:
                                            exists_in_value = True

                                        if not exists_in_value:
                                            print(
                                                f"{monitor_name} does not exist anymore on the agent "
                                                f"and has been deleted on {client_name} / {site_name} / {hostname}"
                                            )
                                            safe_api_call(api.delete_monitor, child_monitor_id)

                            for monitor in relevant_monitors:
                                if monitor.get('type') == 'http':
                                    monitor_name = monitor.get('name')
                                    child_monitor_id = monitor.get('id')
                                    exists_in_value = False

                                    for value in filtered_values:
                                        http_urls_matches = re.findall(
                                            r'HTTP:\s*((?:[^\n]+\n?)+)', value, re.DOTALL
                                        )
                                        if http_urls_matches:
                                            for match in http_urls_matches:
                                                urls = match.strip().split('\n')
                                                for raw_url in urls:
                                                    raw_url = raw_url.strip()
                                                    full_url = normalize_url(raw_url)
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
                                        print(
                                            f"{monitor_name} does not exist anymore on the agent "
                                            f"and has been deleted on {client_name} / {site_name} / {hostname}"
                                        )
                                        safe_api_call(api.delete_monitor, child_monitor_id)

                            for monitor in relevant_monitors:
                                if monitor.get('type') == 'keyword':
                                    monitor_name = monitor.get('name')
                                    child_monitor_id = monitor.get('id')
                                    exists_in_value = False

                                    for value in filtered_values:
                                        keyword_urls_matches = re.findall(
                                            r'KEYWORD:\s*((?:[^\n]+\n?)+)', value, re.DOTALL
                                        )
                                        if keyword_urls_matches:
                                            for match in keyword_urls_matches:
                                                urls = match.strip().split('\n')
                                                for entry in urls:
                                                    entry = entry.strip()
                                                    if ':' in entry:
                                                        base_url_raw, keyword = entry.rsplit(':', 1)
                                                    else:
                                                        base_url_raw = entry
                                                        keyword = 'test'

                                                    full_url = normalize_url(base_url_raw)
                                                    keyword = keyword.strip()
                                                    expected_name = f"{full_url} - {keyword} [{agent_id_5_char}]"
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
                                        print(
                                            f"{monitor_name} does not exist anymore on the agent "
                                            f"and has been deleted on {client_name} / {site_name} / {hostname}"
                                        )
                                        safe_api_call(api.delete_monitor, child_monitor_id)

                            print()
                            time.sleep(1)

                        empty_values = [
                            cf for cf in agent['custom_fields']
                            if cf.get('field') == custom_field_id and not cf.get('value')
                        ]

                        if empty_values:
                            agent_id = agent.get('agent_id', 'N/A')
                            default_hostname = agent.get('hostname', 'N/A')
                            site_name = agent.get('site_name', 'N/A')
                            client_name = agent.get('client_name', 'N/A')

                            agent_id_5_char = agent_id[:5]
                            hostname = f"{default_hostname} [{agent_id_5_char}]"

                            relevant_monitors = api.get_monitors()

                            for monitor in relevant_monitors:
                                monitor_name = monitor.get('name')
                                monitor_id = monitor.get('id')
                                monitor_child = monitor.get('childrenIDs', [])

                                if monitor_name == hostname:
                                    for child in monitor_child:
                                        child_monitor_name = api.get_monitor(child).get('name', 'Unknown')
                                        print(
                                            f"{child_monitor_name} does not exist anymore on the agent "
                                            f"and has been deleted on {client_name} / {site_name} / {hostname}"
                                        )
                                        safe_api_call(api.delete_monitor, child)

                            time.sleep(1)

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
                                            safe_api_call(api.delete_monitor, monitor_id)
                                            NoSubMonitor = True

                                time.sleep(1)

                time.sleep(2)

            else:
                print("Unexpected data format received.")

        else:
            print(f"Request failed. Status code: {response.status_code}")
            print(f"Error message: {response.text}")

    except requests.exceptions.RequestException as e:
        print(f"An error occurred during the request: {e}")

    api.disconnect()
