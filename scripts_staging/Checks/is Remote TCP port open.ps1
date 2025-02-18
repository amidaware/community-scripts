<#
.SYNOPSIS
    Checks if a TCP port is open on a remote machine based on the environment variables "TCP_HOST" and "TCP_PORT".

.DESCRIPTION
    This script checks if a TCP port on a remote host is open using `Test-NetConnection`.
    If unavailable, it falls back to `System.Net.Sockets.TcpClient`.

    If the port is closed or invalid, the script exits with status 1.

.EXAMPLE
    TCP_HOST=example.com
    TCP_PORT=443

.NOTES
    Author: SAN
    Date: 07.02.2025
    #public
#>

# Get environment variables
$hostName = [System.Environment]::GetEnvironmentVariable("TCP_HOST")
$portStr = [System.Environment]::GetEnvironmentVariable("TCP_PORT")

# Validate inputs
if (-not $hostName) {
    Write-Output "Error: Environment variable 'TCP_HOST' is not set."
    exit 1
}

$port = 0
if (-not $portStr -or -not [int]::TryParse($portStr, [ref]$port) -or $port -lt 1) {
    Write-Output "Error: Environment variable 'TCP_PORT' is not set or invalid."
    exit 1
}

# Use Test-NetConnection if available
if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
    $tcpConnection = Test-NetConnection -ComputerName $hostName -Port $port
    if ($tcpConnection.TcpTestSucceeded) {
        Write-Output "OK: Port $port on $hostName is open."
        exit 0
    } else {
        Write-Output "KO: Port $port on $hostName is not open."
        exit 1
    }
} else {
    # Fallback to TcpClient if Test-NetConnection is unavailable
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($hostName, $port)
        Write-Output "OK: Port $port on $hostName is open."
        $tcpClient.Close()
        exit 0
    } catch {
        Write-Output "KO: Port $port on $hostName is not open."
        exit 1
    }
}
