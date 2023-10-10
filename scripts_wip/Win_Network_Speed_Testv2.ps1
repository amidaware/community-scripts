<#
      .SYNOPSIS
      This will download and run iperf to check network speeds, you need one machine on the network as a server and another as a client.
      .PARAMETER Mode
      The only mode parameter is server, set by using -mode server. Obviously this will only work in-LAN and server mode will be killed after script timeout.
      .PARAMETER IP
      Set IP but using -IP IPADDRESS. Not to be used with server mode
      .PARAMETER Seconds
      Client tests default to 3 seconds unless you want to run the tests longer. 
      .EXAMPLE
      Server mode 
      -mode server
      .EXAMPLE
      Client mode 
      -IP 192.168.11.18
      .EXAMPLE
      -IP 192.168.11.18 -Seconds 10
      .NOTES
      3/30/2022 v1 dinger1986 initial release
      9/20/2023 v2 silversword411 adding -Seconds param. Updated to recommended folders. Updating default script timeout to 600 seconds for server mode. Recommend setting up a permanent iperf3 server to run against.

  #>

  param (
    [string] $IP,
    [int] $Seconds,
    [string] $Mode
)

# Check if $Seconds is not specified or 0 and set default value
if (-not $Seconds) {
    $Seconds = 3
}

If (!(test-path $env:programdata\TacticalRMM\temp\)) {
    New-Item -ItemType Directory -Force -Path $env:programdata\TacticalRMM\temp\
}
If (!(test-path $env:programdata\TacticalRMM\toolbox\)) {
    New-Item -ItemType Directory -Force -Path $env:programdata\TacticalRMM\toolbox\
}
If (!(test-path $env:programdata\TacticalRMM\toolbox\iperf3)) {
    New-Item -ItemType Directory -Force -Path $env:programdata\TacticalRMM\toolbox\iperf3\
}

Set-Location $env:programdata\TacticalRMM\temp\

If (!(test-path "$env:programdata\TacticalRMM\toolbox\iperf3\iperf3.exe")) {
    Write-Output "iperf3.exe doesn't exist, downloading and extracting"
Invoke-WebRequest https://iperf.fr/download/windows/iperf-3.1.3-win64.zip -Outfile iperf3.zip

# Expand and move files to toolbox
expand-archive iperf3.zip
Set-Location $env:programdata\TacticalRMM\temp\iperf3\iperf-3.1.3-win64\
Move-Item .\cygwin1.dll $env:programdata\TacticalRMM\toolbox\iperf3\
Move-Item .\iperf3.exe $env:programdata\TacticalRMM\toolbox\iperf3\

# Cleanup
Set-Location $env:programdata\TacticalRMM\toolbox\
Remove-Item -LiteralPath "$env:programdata\TacticalRMM\temp\iperf3.zip" -Force -Recurse
Remove-Item -LiteralPath "$env:programdata\TacticalRMM\temp\iperf3\" -Force -Recurse
}

if ($Mode -eq "server") {
    Write-Output "Starting iPerf3 Server"
	netsh advfirewall firewall add rule name="iPerf3" dir=in action=allow program="$env:programdata\TacticalRMM\toolbox\iperf3\iperf3.exe" enable=yes
    & '$env:programdata\TacticalRMM\toolbox\iperf3\iperf3.exe' -s
    Start-Sleep -Seconds 599
    taskkill /IM "iPerf3.exe" /F
    exit
}

else {
    Write-Output "#################   TCP Upload   #################"
    & 'C:\ProgramData\TacticalRMM\toolbox\iperf3\iperf3.exe' -c $IP -p 9200 -t $Seconds -bidir
    Write-Output "#################   UDP Upload   #################"
    & 'C:\ProgramData\TacticalRMM\toolbox\iperf3\iperf3.exe' -c $IP -p 9200 -u -b 0 -t $Seconds -bidir
    Write-Output "#################   TCP Download   ##################"
    & 'C:\ProgramData\TacticalRMM\toolbox\iperf3\iperf3.exe' -c $IP -p 9200 -R -t $Seconds -bidir
    Write-Output "#################   UDP Download   #################"
    & 'C:\ProgramData\TacticalRMM\toolbox\iperf3\iperf3.exe' -c $IP -p 9200 -R -u -b 0 -t $Seconds -bidir
}
