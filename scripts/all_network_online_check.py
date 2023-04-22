#!/usr/bin/env python3

__version__ = "0.1.1"
__license__ = "MIT"
__authors__ = "NiceGuyIT"

"""
This PC online check script will alert when a PC comes online. It does this by pinging an IP or host, preferably the
RMM server.

In Tactical RMM, a return code of 0 indicates success.
  - If the ping is successful, a return code of 1 used to indicate failure so an alert can be sent.
  - If the ping is not successful, a return code of 0 is used to indicate success and no alert is sent.

Command line arguments:
  There are no command line arguments. All parameters are passed using environmental variables.

Environmental variables:
  - PING_HOSTNAME: Hostname or IP to ping. Default: localhost
    The hostname or IP to ping. If not set, "localhost" is used.

  - PING_TIMEOUT: Timeout, in seconds. Default: 5
    The timeout in seconds for the ping arguments. The ping command has various timeouts in various arguments on
    different systems. PING_TIMEOUT is used for those arguments. An additional timeout of PING_TIMEOUT + 1 is used
    for Python to time out the exec. The idea is that the ping timeout arguments will cause the exec to return before
    Pythong kills the program.

  - PING_STACKTRACE: Include the stack trace on error?
    If true, the stacktrace is included in the output on failure. This may or may not be useful.
    Note: In true Python sense, the value needs to be PascalCase: True

Possible enhancements:
  Use ping3[1] or tcping[2] which do not require exec'ing an external program. The down side is they require
  installing another module.

[1]: https://pypi.org/project/ping3/
[2]: https://pypi.org/project/tcping/
"""

import os
import platform
import subprocess
import traceback
import sys


def ping(host, timeout, stacktrace):
    """
    ping a host with a timeout and return the result and output. If the "ping" command generates an error,
    the output will include the stacktrace if "stacktrace" is True.

    The timeout is the number of seconds for the ping command options, and number of seconds + 1 for Python to
    time out the ping command. A timeout of 1 or 2 seconds is suggested.

    Remember that a host may not respond to a ping (ICMP) request even if the host name is valid.

    :param host: Hostname to ping
    :param timeout: Timeout for the ping command.
    :param stacktrace: If True, include the stacktrace if an error is encountered.
    :return:
        - success: True if the ping was successful. I.e. if the ping program exited successfully. False otherwise.
        - output: Output of the ping program, including the optional stacktrace.
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

    command = ['ping', *param, host]
    try:

        output = subprocess.check_output(
            command,
            # Add 1 second to allow ping to respond.
            timeout=int(timeout)+1,
            universal_newlines=True,
        )
        success = True
    except subprocess.CalledProcessError as err:
        if stacktrace:
            output = f"""Failed to execute ping.
command: {' '.join(command)}
{traceback.format_exc()}
{err}
"""
        else:
            output = f"""Failed to execute ping.
{err}
"""
        success = False
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
        success = False

    return success, output


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

    success, output = ping(**{
        "host": ping_hostname,
        "timeout": ping_timeout,
        "stacktrace": ping_stacktrace,
    })

    # In Tactical terms, a successful ping means the agent is online. The exit code is used to trigger an alert.
    if success:
        print("Success!")
        print(output)
        # Exit with failure; send alert
        return 1
    else:
        print(output)
        # Exit with success; do not send alert
        return 0


if __name__ == '__main__':
    sys.exit(main())
