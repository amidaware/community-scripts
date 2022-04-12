<#
Requires client or site variable for nextdns as "NextDNS" and action as either install, uninstall, start, stop, restart or upgrade (install is the default)
NextDNS is the ID of the NextDNS Configuration obtained from https://my.nextdns.io/
This script will also install the NextDNS root certificate by default, to allow for a pretty block page
Syntax:
-nextdns {{site.NextDNS}} -action {(install) | uninstall | start | stop | restart | upgrade}
#>
param (
   [string] $nextdns,
   [string] $action
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url32 = "https://github.com/nextdns/nextdns/releases/download/v1.37.11/nextdns_1.37.11_windows_386.zip"
$url64 = "https://github.com/nextdns/nextdns/releases/download/v1.37.11/nextdns_1.37.11_windows_amd64.zip"
$cert = "https://nextdns.io/ca"
$ErrorCount = 0

if (!$nextdns) {
    write-output "Variable not specified NextDNS, please add the NextDNS ID to the custom field under the site, Example Value: `"d87mu`" `n"
    $ErrorCount += 1
}

if (!$ErrorCount -eq 0) {
exit 1
}
if ($action -eq "uninstall") {
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "uninstall" -Wait
    Write-Output "NextDNS Uninstalled"
    exit 0
} elseif ($action -eq "stop") {
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "stop" -Wait
    Write-Output "NextDNS Stopped"
    exit 0
} elseif ($action -eq "start") {
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "start" -Wait
    Write-Output "NextDNS Started"
    exit 0
} elseif ($action -eq "restart") {
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "restart" -Wait
    Write-Output "NextDNS Restarted"
    exit 0
} elseif ($action -eq "upgrade") {
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "upgrade" -Wait
    Write-Output "NextDNS Upgraded"
    exit 0
} else {
try {
    # If 32-bit
    if ([System.IntPtr]::Size -eq 4) {
    Invoke-WebRequest -Uri "$url32" -OutFile "$($ENV:Temp)\nextdns.zip"
    Expand-Archive "$($ENV:Temp)\nextdns.zip" -DestinationPath "c:\Program Files\NextDNS" -Force
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "install -config $nextdns -report-client-info -auto-activate" -Wait
    Write-Output "Installed NextDNS"
    Invoke-WebRequest -Uri "$cert" -OutFile "$($ENV:Temp)\NextDNS.cer"
    Import-Certificate -FilePath "$($ENV:Temp)\NextDNS.cer" -CertStoreLocation "Cert:\LocalMachine\Root" -Verbose
    Remove-Item -recurse "$($ENV:Temp)\NextDNS.cer"
    Remove-Item -recurse "$($ENV:Temp)\nextdns.zip"
    Write-Output "Installed Certificate"
    exit 0
    } else {
    Invoke-WebRequest -Uri "$url64" -OutFile "$($ENV:Temp)\nextdns.zip"
    Expand-Archive "$($ENV:Temp)\nextdns.zip" -DestinationPath "c:\Program Files\NextDNS" -Force
    Start-Process -FilePath "c:\Program Files\NextDNS\nextdns.exe" -ArgumentList "install -config $nextdns -report-client-info -auto-activate" -Wait    
    Write-Output "Installed NextDNS"
    Invoke-WebRequest -Uri "$cert" -OutFile "$($ENV:Temp)\NextDNS.cer"
    Import-Certificate -FilePath "$($ENV:Temp)\NextDNS.cer" -CertStoreLocation "Cert:\LocalMachine\Root" -Verbose
    Remove-Item -recurse "$($ENV:Temp)\NextDNS.cer"
    Remove-Item -recurse "$($ENV:Temp)\nextdns.zip"
    Write-Output "Installed Certificate"
    exit 0
    }
 
}

catch {
    Write-Host "NextDNS Command has Failed: $($_.Exception.Message)"
    exit 1
}
}
