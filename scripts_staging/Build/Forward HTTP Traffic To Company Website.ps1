<#
.SYNOPSIS
    Incoming traffic for HTTP and HTTPS destined for the domain controlleris forwarded to the company's website

.DESCRIPTION
    This script is designed to set up port forwarding on a domain controller to forward traffic from port 80 (HTTP) 
    and port 443 (HTTPS) to a website associated with the domain.
    This is done to allow having the same AD domain as the company website.

    The script performs the following actions:
        1. Checks if the script is running on a domain controller.
        2. Retrieves the domain name of the device.
        3. Resolves the public IP address of the domain using a specified DNS server.
        4. Configures port proxy rules to forward traffic from port 80 and port 443 on the domain controller 
        to the resolved IP address.
        5. Creates a single Windows Firewall rule to allow inbound traffic on ports 80 and 443 from the local subnet only.

.NOTES
    Author: SAN
    Date: 15.08.24
    #public

.CHANGELOG
    11.12.24 SAN Added a var for DNS srv

#>

# Check if the machine is a domain controller
$isDomainController = (Get-WmiObject -Class Win32_ComputerSystem).DomainRole -eq 5

if (-not $isDomainController) {
    Write-Output "Error: This script can only be run on a domain controller."
    exit 1
}

# Get the domain name of the device
$domainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain
Write-Output "Local domain: $domainName"
# Resolve the main local IP address (excluding loopback and other non-primary IPs)
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -ne "Loopback Pseudo-Interface 1"} | Sort-Object -Property AddressFamily,PrefixLength -Descending | Select-Object -First 1).IPAddress
Write-Output "Local ip: $localIP"

# Get the DNS server from the environment variable, defaulting to 9.9.9.9 if not set
$dnsServer = [System.Environment]::GetEnvironmentVariable('DNS_SERVER')
if (-not $dnsServer) {
    $dnsServer = '9.9.9.9'
}
Write-Output "Using DNS server: $dnsServer"

# Resolve the IP address of the domain using the specified DNS server
$connectIP = Resolve-DnsName -Name $domainName -Server $dnsServer | Where-Object { $_.QueryType -eq "A" } | Select-Object -ExpandProperty IPAddress
Write-Output "Resolved public ip: $connectIP"
if (-not $connectIP) {
    Write-Output "Error: Could not resolve the IP address for $domainName."
    exit 1
}

# Apply the port proxy for HTTPS (port 443)
Write-Output "netsh interface portproxy add v4tov4 listenport=443 listenaddress=$localIP connectport=443 connectaddress=$connectIP"
netsh interface portproxy add v4tov4 listenport=443 listenaddress=$localIP connectport=443 connectaddress=$connectIP

# Apply the port proxy for HTTP (port 80)
Write-Output "netsh interface portproxy add v4tov4 listenport=80 listenaddress=$localIP connectport=80 connectaddress=$connectIP"
netsh interface portproxy add v4tov4 listenport=80 listenaddress=$localIP connectport=80 connectaddress=$connectIP

Write-Output "Configuration of the firewall"
# Apply a single firewall rule for both ports 80 and 443 allowing traffic from the local subnet only
New-NetFirewallRule -DisplayName 'Open Ports 80 and 443 (LocalSubnet)' -Direction Inbound -LocalPort 80,443 -Protocol TCP -Action Allow -RemoteAddress LocalSubnet

Write-Output "Port proxy configuration and firewall rules have been applied successfully."
