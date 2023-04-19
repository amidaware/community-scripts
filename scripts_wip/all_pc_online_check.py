#!/usr/bin/env python3

# This script will alert when a PC comes online. It does this by pinging the rmm server.
#
# Possible enhancements:
#   Use ping3[1] or tcping[2] which do not require exec'ing an external program. The down side is they require
#   installing another module.
#
# [1]: https://pypi.org/project/ping3/
# [2]: https://pypi.org/project/tcping/

import os
import platform
import subprocess
import traceback
import sys


def ping(host, timeout, stacktrace):
    """
    Returns True if host (str) responds to a ping request.
    Remember that a host may not respond to a ping (ICMP) request even if the host name is valid.
    It takes about
    """

    if host == "":
        output = "Error: Hostname is empty"
        print(output)
        return False, output

    # Number of packets to send.
    count = 1

    # Option for the number of packets as a function of
    if platform.system().lower() == 'windows':
        # Windows
        # -w timeout
        #    Timeout in milliseconds to wait for each reply.
        param = ['-w', f"{timeout * 1000}", '-n', f"{count}"]
    elif platform.system().lower() == 'darwin':
        # macOS
        # -W waittime
        #    Time in milliseconds to wait for a reply for each packet sent.
        # -i wait
        #    Wait "wait" seconds between sending each packet.
        param = ['-W', f"{timeout * 1000}", '-i', f"{timeout}", '-c', f"{count}"]
    else:
        # Linux/macOS
        # -w deadline
        #    Specify a timeout, in seconds, before ping exits regardless of how many packets have been sent or received.
        # -W timeout
        #    Time to wait for a response, in seconds.
        # -i interval
        #    Wait interval seconds between sending each packet.
        param = ['-w', f"{timeout}", '-W', f"{timeout}", '-i', f"{timeout}", '-c', f"{count}"]

    # Building the command. Ex: "ping -c 1 google.com"
    command = ['ping', *param, host]

    # Debugging info if you need it
    # print(f"platform: {platform.system()}")
    # print(f"command: {command}")
    try:

        output = subprocess.check_output(
            command,
            # Add 1 second to allow ping to respond.
            timeout=int(timeout)+1,
            universal_newlines=True,
        )
        result = True
    except subprocess.CalledProcessError as err:
        if stacktrace:
            output = f"""Failed to execute ping.
command: {command}
{traceback.format_exc()}
{err}
"""
        else:
            output = f"""Failed to execute ping.
command: {command}
{err}
"""
        result = False
    except subprocess.TimeoutExpired as err:
        if stacktrace:
            output = f"""Ping command timed out after '{timeout + 1}' seconds.
command: {' '.join(command)}
{traceback.format_exc()}
{err}
"""
        else:
            output = f"""Ping command timed out after '{timeout + 1}' seconds.
command: {' '.join(command)}
{err}
"""
        result = False

    return result, output


def main():
    default_hostname = 'localhost'
    default_timeout = '5'

    ping_hostname = os.environ.get('PING_HOSTNAME')
    ping_timeout = os.environ.get('PING_TIMEOUT')
    ping_stacktrace = os.environ.get('PING_STACKTRACE', False)

    if ping_hostname is None:
        ping_hostname = default_hostname
        print(f"PING_HOSTNAME was not provided. Using '{default_hostname}'")
    if ping_timeout is None:
        ping_timeout = default_timeout
        print(f"PING_TIMEOUT was not provided. Using '{default_timeout}'")

    if not ping_timeout.isdigit():
        print(f"PING_TIMEOUT is not an integer: '{ping_timeout}'")
        return 2
    ping_timeout = int(ping_timeout)

    result, output = ping(**{
        "host": ping_hostname,
        "timeout": ping_timeout,
        "stacktrace": ping_stacktrace,
    })
    if result:
        print("Success!")
        print(output)
        # In Tactical terms, a successful ping means the agent is online. The exit code is used to trigger an alert.
        # Exit with failure; send alert
        return 1
    else:
        print("Failed!")
        print(output)
        # In Tactical terms, a successful ping means the agent is online. The exit code is used to trigger an alert.
        # Exit with success; do not send alert
        return 0


if __name__ == '__main__':
    sys.exit(main())
