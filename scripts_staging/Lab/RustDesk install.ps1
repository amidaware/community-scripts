<#

#public
#alternative experimental rustdesk installer/configuration 

exemple var:
rustdeskkey={{global.rustdeskkey}}
rendezvousServer=192.x.x.x
customRendezvousServer=192.x.x.x

#>
$ErrorActionPreference = 'SilentlyContinue'

$ServiceName = 'Rustdesk'
$UserProfileConfigPath = "C:\Users\$username\AppData\Roaming\RustDesk\config\RustDesk2.toml"
$LocalServiceConfigPath = "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml"

# Configuration content
$rendezvousServer = $env:rendezvousServer
$customRendezvousServer = $env:customRendezvousServer
$key = $env:rustdeskkey

# Hardcoded values
$natType = 2
$serial = 0
# Optional Values
# $relayServer = 'IPADDRESS'
# $apiServer = 'https://IPADDRESS'

# Install Rustdesk using Chocolatey (latest version)
choco install rustdesk -y

# Check and start Rustdesk service if necessary
$arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($arrService -eq $null) {
    Start-Sleep -Seconds 20
}

while ($arrService.Status -ne 'Running') {
    Start-Service $ServiceName
    Start-Sleep -Seconds 5
    $arrService.Refresh()
}
net stop $ServiceName

# Get current username
$username = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]

# Update RustDesk configuration for the user and local service
$RustDeskConfigContent = @"
rendezvous_server = '$rendezvousServer'
nat_type = $natType
serial = $serial

[options]
custom-rendezvous-server = '$customRendezvousServer'
key = '$key'
# relay-server = 'IPADDRESS'  # Optional
# api-server = 'https://IPADDRESS'  # Optional
"@

Remove-Item $UserProfileConfigPath -ErrorAction SilentlyContinue
New-Item -Path $UserProfileConfigPath -ItemType File -Force | Out-Null
Set-Content -Path $UserProfileConfigPath -Value $RustDeskConfigContent

Remove-Item $LocalServiceConfigPath -ErrorAction SilentlyContinue
New-Item -Path $LocalServiceConfigPath -ItemType File -Force | Out-Null
Set-Content -Path $LocalServiceConfigPath -Value $RustDeskConfigContent

# Start the Rustdesk service
net start $ServiceName