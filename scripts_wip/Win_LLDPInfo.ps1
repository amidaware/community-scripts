.<#
.SYNOPSIS
    Gets switch name and port that the computer is plugged into
.DESCRIPTION
    Uses PSDiscoveryProtocol module to query the switch port
    https://github.com/lahell/PSDiscoveryProtocol
#>

if ('NuGet' -notin (Get-PackageProvider).Name) {
    Install-PackageProvider -Name NuGet -Force | Out-Null
}

if ('PSDiscoveryProtocol' -notin (Get-InstalledModule).Name) {
    Install-Module -Name PSDiscoveryProtocol -Repository PSGallery -Confirm:$false -Force | Out-Null
}
Set-ExecutionPolicy Bypass -Scope Process
#if your computer is hooked up through an IP phone, it will show the phone as the switch upon occasion.  This do..until runs until the switch is not the Polycom phone.
#change Polycom to whatever it displays for your phone, or remove lines 19 and 22 if you don't daisychain through an ip phone
do {
    $Packet = Invoke-DiscoveryProtocolCapture -Type LLDP -ErrorAction SilentlyContinue
    $lldp = Get-DiscoveryProtocolData -Packet $Packet
} until ($lldp.Device -notlike "Polycom*")
$lldpinfo = "Switch: $($lldp.Device) - Port: $($lldp.port) - Port Description: $($lldp.portdescription)"
return $lldpinfo
