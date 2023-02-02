<#

.SYNOPSIS
   Runs network scan on the agents network, returns list of IPs that are live. Optionally tries to return RDNS name lookup as well.

.DESCRIPTION
   Run to find all the IPs that are alive on the network based on ICMP

.NOTES
   v1.0 dinger1986
   v1.1 silversword documenting, fixing problem when multiple active NICs etc.
   v1.2 bbrendon. Script never worked. Fixed.
   
.KNOWN ISSUES
 - Script doesn't list host running it
 - Only works correctly on /24 nets
#>

# TODO: might expand to record this then do network intrusion

$ErrorActionPreference = 'silentlycontinue'

$nic = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric | Select-Object -First 1 | Get-NetAdapter).name
$IP = (Get-NetIPAddress -AddressFamily IPV4 -InterfaceAlias $nic).IPAddress

$Subnet = ($IP -split "`r`n" | ForEach-Object {
    ([ipaddress]$_).GetAddressBytes()[0..2] -join '.'
  })

# Write-Output "NIC: $nic"
# Write-Output "IP: $IP"
# Write-Output "Subnet: $Subnet"

$SubNet | ForEach-Object {
    $Net = $_
    1..254 | ForEach-Object {
        Start-Process -WindowStyle Hidden ping.exe -Argumentlist "-n 1 -l 0 -f -i 2 -w 1 -4 $Net.$_"
    }
}
$Computers = (arp.exe -a | Select-String "$SubNet.*dynam") -replace ' +', ', ' |
ConvertFrom-Csv -Header Computername, IPv4, MAC, x, Vendor |
Select-Object Computername, IPv4, MAC

ForEach ($Computer in $Computers) {
  nslookup $Computer.IPv4 | Select-String -Pattern "^Name:\s+([^\.]+).*$" |
  ForEach-Object {
    $Computer.Computername = $_.Matches.Groups[1].Value
  }
}
Write-Output $Computers
