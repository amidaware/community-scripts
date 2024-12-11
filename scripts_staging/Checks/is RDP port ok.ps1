<#
.SYNOPSIS
    Checks if TCP port 3389 (RDP) is open on the local machine.

.DESCRIPTION
    This script attempts to determine if TCP port 3389 is open using the `Test-NetConnection` cmdlet. 
    If `Test-NetConnection` is not available, it falls back to using the `System.Net.Sockets.TcpClient` class to perform the check.
    The script will output whether the port is open or not and exit with a status code of 1 if the port is closed.

.NOTES
    Author: SAN
    Date: 26.09.2024
    #public
#>

$port = 3389
$address = "localhost"

# Try Test-NetConnection if available
if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
    $tcpConnection = Test-NetConnection -ComputerName $address -Port $port
    if ($tcpConnection.TcpTestSucceeded) {
        Write-Output "Port $port is open."
    } else {
        Write-Output "Port $port is not open."
        exit 1
    }
} else {
    # Fallback using TcpClient
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($address, $port)
        Write-Output "Port $port is open."
        $tcpClient.Close()
    } catch {
        Write-Output "Port $port is not open."
        exit 1
    }
}