# Checks for all devices on a network (might expand to record this then do network intrusion)

$ErrorActionPreference= 'silentlycontinue'

$nic = (Get-NetAdapter -Name * -Physical).Name
$IP = (Get-NetIPAddress -AddressFamily IPV4 -InterfaceAlias $nic).IPAddress

$Subnet = ($IP-split "`r`n" | % {
    ([ipaddress]$_).GetAddressBytes()[0..2] -join '.'
})

## Ping subnet
1..254|ForEach-Object{
    Start-Process -WindowStyle Hidden ping.exe -Argumentlist "-n 1 -l 0 -f -i 2 -w 1 -4 $SubNet$_"
}
$Computers =(arp.exe -a | Select-String "$SubNet.*dynam") -replace ' +',','|
  ConvertFrom-Csv -Header Computername,IPv4,MAC,x,Vendor|
                   Select Computername,IPv4,MAC

ForEach ($Computer in $Computers){
  nslookup $Computer.IPv4|Select-String -Pattern "^Name:\s+([^\.]+).*$"|
    ForEach-Object{
      $Computer.Computername = $_.Matches.Groups[1].Value
    }
}
echo $Computers
