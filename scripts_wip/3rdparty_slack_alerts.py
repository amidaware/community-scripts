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

url = 'https://hooks.slack.com/services/XXXXXX/XXXXXX/XXXXXX'
payload = {"text": f"Name: {agent_hostname} \nAlert Message: {alert_message}\nIP: {{agent_local_ips}}"}

r = requests.post(url, data=json.dumps(payload), headers={'Content-Type': 'application/json'})