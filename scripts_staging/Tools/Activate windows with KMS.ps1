<#
.SYNOPSIS
    Script to activate Windows using a KMS server, with support for specifying the server and port via an environment variable.

.DESCRIPTION
    This script checks for the presence of the `kms_server` environment variable. If found, it sets the KMS server and initiates the Windows activation process using the specified server and port. If the `kms_server` is not set, the script prompts the user to set it.

.EXAMPLE
    kms_server=kms.example.com:1688
    kms_server=host:port

.NOTES
    Author: SAN
    Date: 14.11.24
    #public

.CHANGELOG
    11.12.24 SAN Code Cleanup
    16.07.25 SAN added network check + check if activation is successful 

.TODO
    Convert the script to use the PowerShell module as the future of vbs is uncertain.
    see code bellow for prototype

#>
# Check if the 'kms_server' environment variable exists
if (-not $env:kms_server) {
    Write-Host "The 'kms_server' environment variable is not set."
    exit 1
}

# Parse kms_server into host and optional port (defaults to 1688 if not provided)
$rawKmsServer = $env:kms_server
$kmsParts = $rawKmsServer -split ":", 2
$kmsHost = $kmsParts[0]
$kmsPort = if ($kmsParts.Count -eq 2 -and $kmsParts[1]) { $kmsParts[1] } else { "1688" }

Write-Host "Parsed KMS server: Host = $kmsHost, Port = $kmsPort"

# Test TCP connectivity to the KMS server
Write-Host "Testing network connectivity to $kmsHost on port $kmsPort..."
try {
    $testResult = Test-NetConnection -ComputerName $kmsHost -Port ([int]$kmsPort) -WarningAction SilentlyContinue
    if (-not $testResult.TcpTestSucceeded) {
        Write-Host "Network test failed. Cannot reach $kmsHost on port $kmsPort."
        exit 1
    }
    Write-Host "Network test passed. KMS server is reachable."
} catch {
    Write-Host "An error occurred during network test: $_"
    exit 1
}

# Set KMS server
Write-Host "Setting KMS server to: $rawKmsServer..."
try {
    Start-Process -FilePath "cscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /skms $rawKmsServer" -NoNewWindow -Wait -ErrorAction Stop
    Write-Host "Successfully set KMS server."
} catch {
    Write-Host "Failed to set KMS server. Error: $_"
    exit 1
}

# Activate Windows
Write-Host "Activating Windows..."
try {
    Start-Process -FilePath "cscript.exe" -ArgumentList "$env:SystemRoot\System32\slmgr.vbs /ato" -NoNewWindow -Wait -ErrorAction Stop
    Write-Host "Activation command sent."
} catch {
    Write-Host "Windows activation command failed. Error: $_"
    exit 1
}

# Check Windows activation status
Write-Host "Checking Windows activation status..."
try {
    $licenseStatus = (Get-CimInstance -Query "SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseStatus = 1").LicenseStatus
    if ($licenseStatus -eq 1) {
        Write-Host "Windows is activated."
        exit 0
    } else {
        Write-Host "Windows is NOT activated."
        exit 1
    }
} catch {
    Write-Host "Failed to check activation status. Error: $_"
    exit 1
}




<#

# Check if the environment variable 'kms_server' exists
if ($env:kms_server) {
    # Extract the KMS server address and port
    $kmsServerInfo = $env:kms_server
    $kmsServerParts = $kmsServerInfo -split ':'

    if ($kmsServerParts.Length -eq 2) {
        $kmsServer = $kmsServerParts[0]
        $kmsPort = $kmsServerParts[1]
        Write-Host "Found 'kms_server' environment variable: $kmsServer:$kmsPort"

        # Install the slmgr-ps module if it's not already installed
        if (-not (Get-Module -ListAvailable -Name slmgr-ps)) {
            Write-Host "Installing slmgr-ps module..."
            Install-Module -Name slmgr-ps -Force -AllowClobber
        }
        
        # Import the module
        Import-Module -Name slmgr-ps -Force

        # Activate Windows using the KMS server and port extracted
        Write-Host "Activating Windows with KMS server: $kmsServer and port: $kmsPort"
        Start-WindowsActivation -KMSServerFQDN $kmsServer -KMSServerPort $kmsPort

        Write-Host "Windows activation process initiated."
    } else {
        Write-Host "Invalid 'kms_server' format. It should be in the form 'server:port'."
    }
} else {
    Write-Host "The 'kms_server' environment variable is not set."
    Write-Host "Please set the 'kms_server' variable before running the script."
}

#>