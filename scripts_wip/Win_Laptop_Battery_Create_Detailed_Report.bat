If(!(test-path $env:programdata\RMMScripts\))
{
      New-Item -ItemType Directory -Force -Path $env:programdata\TRMMScripts\
}

powercfg /batteryreport /output "$env:programdata\TRMMScripts\battery-report.txt"

get-content '$env:programdata\TRMMScripts\battery-report.txt'
