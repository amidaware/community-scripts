
$CUSTOMER = "CustomerName"
$VPNHOST = "fqdn.customer.name"

Add-VpnConnection -Name "VPN $CUSTOMER" -ServerAddress "$VPNHOST" -TunnelType "SSTP" -EncryptionLevel "Required" -AuthenticationMethod MSChapv2 -SplitTunneling -AllUserConnection -force
# New-ItemProperty -Type DWord -Path HKLM:\System\CurrentControlSet\Services\Sstpsvc\Parameter -Name NoCertRevocationCheck -value "1"