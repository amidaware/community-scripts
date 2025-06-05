#!/usr/bin/python3

"""
This script performs a network scan on a given target or subnet.
It checks if the target hosts are alive, and if ports 80 (HTTP) and 443 (HTTPS) are open, and optionally performs reverse DNS lookups if specified.

Params:
--hostname  Perform reverse DNS lookup
--mac       Include MAC address in output

v1.1 2/2024 silversword411
v1.4 added open port checker
v1.5 5/2/2024 silversword411 integrated reverse DNS lookup into the ping function with 1-second timeout
v1.6 5/31/2024 silversword411 align output to columns and ports low to high
v1.7 2/18/2025 silversword411 fix columns with long host names and added response time
v1.8 5/21/2025 silversword411 added MAC address lookup with --mac option

TODO: Make subnet get automatically detected
TODO: run on linux as well
"""

import socket
import threading
import subprocess
import ipaddress
import re
from collections import defaultdict
import argparse


def get_host_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = "127.0.0.1"
    finally:
        s.close()
    return IP


def ping_ip(ip, alive_hosts, do_reverse_dns):
    try:
        output = subprocess.check_output(
            ["ping", "-n", "1", "-w", "1000", ip],
            stderr=subprocess.STDOUT,
            universal_newlines=True,
        )
        if "Reply from" in output:
            alive_ip = ipaddress.ip_address(ip)
            response_time = re.search(r"time[=<]\s*(\d+)ms", output)
            response_time = int(response_time.group(1)) if response_time else -1

            hostname = "NA"
            if do_reverse_dns:
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    s.settimeout(1)
                    hostname = socket.gethostbyaddr(ip)[0]
                except socket.error:
                    hostname = "unknown"
                finally:
                    s.close()

            alive_hosts.append(
                (alive_ip, hostname, response_time, "")
            )  # Placeholder for MAC
    except Exception:
        pass


def get_mac_address(ip):
    try:
        output = subprocess.check_output(["arp", "-a", ip], universal_newlines=True)
        match = re.search(r"(\w{2}-\w{2}-\w{2}-\w{2}-\w{2}-\w{2})", output)
        return match.group(1) if match else "N/A"
    except Exception:
        return "N/A"


def check_ports(ip, port, open_ports):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(1)
            if s.connect_ex((ip, port)) == 0:
                open_ports[ip].append(port)
    except Exception:
        pass


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Scan network subnet for alive hosts, open ports, and optionally perform reverse DNS or get MAC address."
    )
    parser.add_argument(
        "--hostname", help="Perform reverse DNS lookup", action="store_true"
    )
    parser.add_argument(
        "--mac", help="Include MAC address in output", action="store_true"
    )
    return parser.parse_args()


def main():
    args = parse_arguments()
    host_ip = get_host_ip()
    print(f"Detected Host IP: {host_ip}")

    subnet = ipaddress.ip_network(f"{host_ip}/24", strict=False)
    alive_hosts = []
    open_ports = defaultdict(list)

    threads = []
    for ip in subnet.hosts():
        t = threading.Thread(target=ping_ip, args=(str(ip), alive_hosts, args.hostname))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    if args.mac:
        for i, (ip, hostname, response_time, _) in enumerate(alive_hosts):
            mac = get_mac_address(str(ip))
            alive_hosts[i] = (ip, hostname, response_time, mac)

    alive_hosts.sort(key=lambda x: x[0])

    port_check_threads = []
    for host, _, _, _ in alive_hosts:
        for port in [22, 23, 25, 80, 443, 2525, 8443, 10443, 10000, 20000]:
            t = threading.Thread(target=check_ports, args=(str(host), port, open_ports))
            t.start()
            port_check_threads.append(t)

    for t in port_check_threads:
        t.join()

    max_hostname_length = max(
        (len(hostname) for _, hostname, _, _ in alive_hosts), default=8
    )
    ip_column_width = 16
    hostname_column_width = max(max_hostname_length, 12) + 2
    response_time_column_width = 8
    mac_column_width = 20 if args.mac else 0
    ports_column_width = 50

    header = f"{'IP':<{ip_column_width}}{'(ms)':<{response_time_column_width}}{'Hostname':<{hostname_column_width}}"
    if args.mac:
        header += f"{'MAC Address':<{mac_column_width}}"
    header += f"{'Open Ports':<{ports_column_width}}"
    print(header)
    print("-" * len(header))

    for host, hostname, response_time, mac in alive_hosts:
        ports = sorted(open_ports[str(host)])
        ports_str = ", ".join(map(str, ports))
        response_time_str = f"{response_time} ms" if response_time >= 0 else "N/A"
        line = f"{str(host):<{ip_column_width}}{response_time_str:<{response_time_column_width}}{hostname:<{hostname_column_width}}"
        if args.mac:
            line += f"{mac:<{mac_column_width}}"
        line += f"{ports_str:<{ports_column_width}}"
        print(line)

    print(f"\nTotal count of alive hosts: {len(alive_hosts)}")


if __name__ == "__main__":
    main()
