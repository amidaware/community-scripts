#!/usr/bin/python3

"""
This script performs a network scan on a given target or subnet.
It checks if the target hosts are alive, and if ports 80 (HTTP) and 443 (HTTPS) are open, and optionally performs reverse DNS lookups if specified.
v1.1 2/2024 silversword411
v1.4 added open port checker
v1.5 5/2/2024 integrated reverse DNS lookup into the ping function with 1-second timeout

TODO: Make subnet get automatically detected instead of assuming /24
TODO: Compatible with Linux as well
"""

import socket
import threading
import subprocess
import ipaddress
from collections import defaultdict
import argparse

# Function to get the IP address of the primary network interface
def get_host_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

# Function to ping an IP address, check if it is alive, and optionally perform a reverse DNS lookup
def ping_ip(ip, alive_hosts, do_reverse_dns):
    try:
        output = subprocess.check_output(["ping", "-n", "1", "-w", "1000", ip], stderr=subprocess.STDOUT, universal_newlines=True)
        if "Reply from" in output:
            alive_ip = ipaddress.ip_address(ip)
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
            alive_hosts.append((alive_ip, hostname))
    except Exception:
        pass

# Function to check for open ports
def check_ports(ip, port, open_ports):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(1)
            if s.connect_ex((ip, port)) == 0:
                open_ports[ip].append(port)
    except Exception:
        pass

# Parse command-line arguments
def parse_arguments():
    parser = argparse.ArgumentParser(description="Scan network subnet for alive hosts, open ports, and optionally perform reverse DNS lookup.")
    parser.add_argument("--hostname", help="Perform reverse DNS lookup", action="store_true")
    return parser.parse_args()

# Main function to detect the subnet and scan it
def main():
    args = parse_arguments()
    host_ip = get_host_ip()
    print(f"Detected Host IP: {host_ip}")

    subnet = ipaddress.ip_network(f'{host_ip}/24', strict=False)
    alive_hosts = []
    open_ports = defaultdict(list)

    threads = []
    for ip in subnet.hosts():
        t = threading.Thread(target=ping_ip, args=(str(ip), alive_hosts, args.hostname))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    # Sort the alive hosts numerically
    alive_hosts.sort(key=lambda x: x[0])

    # Launch port checks
    port_check_threads = []
    for host, _ in alive_hosts:
        for port in [22, 23, 25, 80, 443, 2525, 8443, 10443, 10000, 20000]:
            t = threading.Thread(target=check_ports, args=(str(host), port, open_ports))
            t.start()
            port_check_threads.append(t)
    
    for t in port_check_threads:
        t.join()

    print(f"Alive hosts in the subnet {subnet}:")
    for host, hostname in alive_hosts:
        ports = ', '.join(str(port) for port in open_ports[str(host)])
        print(f"IP: {host}, {hostname}, Open Ports: {ports}")

    print(f"\nTotal count of alive hosts: {len(alive_hosts)}")

if __name__ == "__main__":
    main()