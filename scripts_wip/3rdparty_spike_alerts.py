# from superdry

import requests
import json
import sys

agent_hostname = sys.argv[1]
agent_description = sys.argv[2]
agent_local_ips = sys.argv[3]
client_name = sys.argv[4]
site_name = sys.argv[5]
alert_message = sys.argv[6]
alert_severity = sys.argv[7]
spike_alerts = sys.argv[8].replace("'", "")
status = sys.argv[9]

webhook_url =  f'https://hooks.spike.sh/{spike_alerts}/push-events'
sev_lookup = {'warning': 'sev3', 'error':'sev2'}
print(webhook_url)
# title should be VM Name/IP/Issue (e.g. PVM430 - 10.11.205.12 - Memory Usage)

if status == 'alert':
    data = {
        'title': f'{agent_hostname} - {agent_local_ips} - {alert_message}',
        'body': f'Name: {agent_hostname} Description: {agent_description}, Alert Message: {alert_message}',
        'severity': sev_lookup.get(alert_severity, 'sev3'),
        'priority': 'p3'
    }
elif status == 'resolve':
    data = {
        'title': f'{agent_hostname} - {agent_local_ips} - {alert_message}',
        'body': f'Name: {agent_hostname} Description: {agent_description}, Alert Message: {alert_message}',
        'status': 'resolve',
    }

r = requests.post(webhook_url, data=json.dumps(data), headers={'Content-Type': 'application/json'})
