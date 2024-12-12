<#
.SYNOPSIS
    Checks if a TCP port is open on the local machine based on the environment variable "TCP_PORT".

.DESCRIPTION
    This script checks if the TCP port defined by the environment variable "TCP_PORT" is open using the `Test-NetConnection` cmdlet. 
    If `Test-NetConnection` is not available, it falls back to using the `System.Net.Sockets.TcpClient` class to perform the check.
    Additionally, it will display the executable and process information that is holding the port open.
    If the application is linked to a service, the service name and status will be displayed.
    The script will exit with a status code of 1 if the port is closed or if the environment variable is not set.

.EXEMPLE
    TCP_PORT=3435

.NOTES
    Author: SAN
    Date: 01.10.2024
    #public

.CHANGELOG

#>

$portStr = [System.Environment]::GetEnvironmentVariable("TCP_PORT")

# Initialize the port variable
$port = 0

# Check if the environment variable is set and valid
if (-not $portStr -or -not [int]::TryParse($portStr, [ref]$port) -or $port -lt 1) {
    Write-Output "Error: Environment variable 'TCP_PORT' is not set or is invalid."
    exit 1
}

$address = "localhost"

Write-Output "Checking connectivity to $address on port $port..."

# Try Test-NetConnection if available
if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
    $tcpConnection = Test-NetConnection -ComputerName $address -Port $port
    if ($tcpConnection.TcpTestSucceeded) {
        Write-Output "Success: Port $port on $address is open."
    } else {
        Write-Output "Failure: Port $port on $address is not open."
        Write-Output "Details: TCP connection test failed."
        exit 1
    }
} else {
    # Fallback using TcpClient
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($address, $port)
        Write-Output "Success: Port $port on $address is open."
        $tcpClient.Close()
    } catch {
        Write-Output "Failure: Port $port on $address is not open."
        Write-Output "Details: TCP connection test threw an exception."
        exit 1
    }
}

# Find the process holding the port open for incoming connections only
$netstatOutput = netstat -ano | Select-String ":$port\s" | ForEach-Object { $_.Line } | Where-Object { $_ -match 'LISTENING' -and $_ -match '0.0.0.0|127.0.0.1' }
if ($netstatOutput) {
    $portPID = $netstatOutput -replace '^.*\s+(\d+)$', '$1'
    $process = Get-Process -Id $portPID -ErrorAction SilentlyContinue

    if ($process) {
        Write-Output "The port $port is being used by the process '$($process.ProcessName)' (PID: $portPID)."
        Write-Output "Executable Path: $($process.Path)"
        
        # Check if the process is linked to a service
        $service = Get-WmiObject Win32_Service | Where-Object { $_.ProcessId -eq $portPID }
        if ($service) {
            Write-Output "This process is linked to the service: '$($service.Name)'"
            Write-Output "Service Display Name: $($service.DisplayName)"
            Write-Output "Service Status: $($service.State)"
        } else {
            Write-Output "This process is not linked to any service."
        }
    } else {
        Write-Output "Unable to retrieve the process details for PID $portPID."
    }
} else {
    Write-Output "No process is currently using port $port for incoming connections."
}