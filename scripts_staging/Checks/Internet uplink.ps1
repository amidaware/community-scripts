<#
.SYNOPSIS
    Tests connectivity to a predefined list of IP addresses either randomly or all at once.

.DESCRIPTION
    This script checks network connectivity by pinging a list of predefined IP addresses. 
    The user can choose to test all the IP addresses or a randomly selected one.
    If a ping fails, the script exits with a status code of 1.

.PARAMETER TestAll
    A switch parameter to test all IP addresses in the list.
    If not specified, the script selects a random IP address for testing.

.EXAMPLE
    -TestAll

.NOTES
    Author: SAN
    Date: ???
    #public

.CHANGELOG

.TODO
    Include customizable input for the list of IP addresses.
    Enhance error handling for unreachable hosts.
    for test all to env
    tnc has some relability issue maybe use normal ping
#>


param (
    [switch]$TestAll
)

# List of IP addresses with their respective owners
$ipAddresses = @(
    @{ IP="8.8.8.8"; Owner="Google DNS" },
    @{ IP="8.8.4.4"; Owner="Google DNS" },
    @{ IP="1.1.1.1"; Owner="Cloudflare DNS" },
    @{ IP="1.0.0.1"; Owner="Cloudflare DNS" },
    @{ IP="208.67.222.222"; Owner="OpenDNS" },
    @{ IP="208.67.220.220"; Owner="OpenDNS" },
    @{ IP="9.9.9.9"; Owner="Quad9 DNS" },
    @{ IP="149.112.112.112"; Owner="Quad9 DNS" },
    @{ IP="13.107.42.14"; Owner="Microsoft Azure" },
    @{ IP="20.190.160.1"; Owner="Microsoft Azure" },
    @{ IP="54.239.28.85"; Owner="Amazon AWS" },
    @{ IP="205.251.242.103"; Owner="Amazon AWS" }
)

$pingFailed = $false

if ($TestAll) {
    # Test all IP addresses
    foreach ($entry in $ipAddresses) {
        $ip = $entry.IP
        $owner = $entry.Owner
        $pingResult = Test-Connection -ComputerName $ip -Count 1 -Quiet

        if (-not $pingResult) {
            Write-Host "Ping to $ip ($owner) failed."
            $pingFailed = $true
        } else {
            Write-Host "Ping to $ip ($owner) succeeded."
        }
    }

    if ($pingFailed) {
        exit 1
    }
} else {
    # Randomly select an IP address
    $randomEntry = $ipAddresses | Get-Random
    $randomIp = $randomEntry.IP
    $owner = $randomEntry.Owner

    # Ping the selected IP address
    $pingResult = Test-Connection -ComputerName $randomIp -Count 1 -Quiet

    # Check the result of the ping and exit with status code 1 if it fails
    if (-not $pingResult) {
        Write-Host "Ping to $randomIp ($owner) failed."
        exit 1
    } else {
        Write-Host "Ping to $randomIp ($owner) succeeded."
    }
}