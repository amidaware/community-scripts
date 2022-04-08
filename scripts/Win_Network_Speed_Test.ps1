<#
      .SYNOPSIS
      This will download and run iperf to check network speeds, you need one machine on the network as a server and another as a client. 
      .PARAMETER Mode
      The only mode parameter is server, set by using -mode server
      .PARAMETER IP
      Set IP but using -IP IPADDRESS. Not to be used with server mode
      .EXAMPLE
      Server mode -mode server 
      .EXAMPLE
      Client mode -IP 192.168.11.18
  #>

param (
    [string] $IP,
    [string] $Mode
)

If (!(test-path "c:\temp")) {
    New-Item -ItemType Directory -Force -Path "c:\temp"
}

Set-Location c:\temp

If (!(test-path "C:\Program Files\TacticalAgent\iperf3.exe")) {
Invoke-WebRequest https://iperf.fr/download/windows/iperf-3.1.3-win64.zip -Outfile iperf3.zip

expand-archive iperf3.zip

Set-Location C:\TEMP\iperf3\iperf-3.1.3-win64

Move-Item .\cygwin1.dll 'C:\Program Files\TacticalAgent\'
Move-Item .\iperf3.exe 'C:\Program Files\TacticalAgent\'

Start-Process sleep -Seconds 5

Remove-Item -LiteralPath "c:\temp\iperf3.zip" -Force -Recurse
}

if ($Mode -eq "server") {
    Write-Output "Starting iPerf3 Server"
	netsh advfirewall firewall add rule name="iPerf3" dir=in action=allow program="C:\Program Files\TacticalAgent\iperf3.exe" enable=yes
    & 'C:\Program Files\TacticalAgent\iperf3.exe' -s
    Start-Sleep -Seconds 20
    taskkill /IM "iPerf3.exe" /F
    exit
}

else {
    & 'C:\Program Files\TacticalAgent\iperf3.exe' -c $IP
}
