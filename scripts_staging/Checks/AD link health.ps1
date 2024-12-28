<#
.SYNOPSIS
    This script performs connectivity tests for Active Directory Domain Controllers, 
    checking various services and protocols to ensure proper functionality. 
    It includes DNS resolution, and service port checks for LDAP, SMB, RPC, and Kerberos authentication.

.DESCRIPTION
    The script first checks if the local machine is part of a domain. 
    It then discovers all domain controllers in the domain and performs connectivity tests on each. 
    Results are logged, and the script exits with a status code indicating success or failure based on the results.

.NOTE
    Author: SAN
    Date: 04.10.24
    #public

.CHANGELOG
    26.11.24 SAN big code cleanup, bug fix, removal of debug to help with cleanup
    17.12.24 SAN fixed couting issue, added a fallback in case tnc does not work

.TODO
    Make ldap rpc smb followup querries to test that the protocol works 
    re-implement debug 

#>


# Define ports commonly used by Active Directory services
$portsToCheck = @{
    'DNS'                        = 53
    'RPC Endpoint Mapper'        = 135
    'SMB'                        = 445
    'LDAP'                       = 389
    'LDAP (SSL)'                 = 636
    'Kerberos'                   = 88
    'Kerberos Entra'             = 464
    'Global Catalog LDAP'        = 3268
    'Global Catalog LDAP (SSL)'  = 3269
#    'NetBIOS Name Service'      = 137
#    'NetBIOS Datagram Service'  = 138
#    'NetBIOS Session Service'   = 139
}


# Function to perform DNS resolution test
function Test-DnsResolution {
    param (
        [string]$ADDomainController
    )
    try {
        $dnsResult = [System.Net.Dns]::GetHostAddresses($ADDomainController)
        if ($dnsResult) {
            $status = "OK"
        } else {
            $status = "KO"
        }
    } catch {
        $status = "KO"
    }

    [PSCustomObject]@{
        TestName  = "DNS Resolution"
        Status    = $status
        TargetDC  = $ADDomainController
    }
}

# Function to test a specific port connection
function Test-PortConnection {
    param (
        [string]$ADDomainController,
        [int]$Port,
        [string]$ServiceName
    )

    # Try Test-NetConnection first
    try {
        $connection = Test-NetConnection -ComputerName $ADDomainController -Port $Port -WarningAction SilentlyContinue
        $status = if ($connection.TcpTestSucceeded) { "OK" } else { "KO" }
    } catch {
        # Fallback to System.Net.Sockets.TcpClient
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        try {
            $tcpClient.Connect($ADDomainController, $Port)
            $status = "OK"
        } catch {
            $status = "KO"
        } finally {
            $tcpClient.Close()
        }
    }

    # Return the result
    [PSCustomObject]@{
        TestName  = "Port $Port ($ServiceName)"
        Status    = $status
        TargetDC  = $ADDomainController
    }
}


# Function to perform Kerberos authentication test
function Test-KerberosAuthentication {
    param (
        [string]$ADDomainController
    )
    $kerbTicket = klist
    $status = if ($kerbTicket) { "OK" } else { "KO" }

    [PSCustomObject]@{
        TestName  = "Kerberos Authentication"
        Status    = $status
        TargetDC  = $ADDomainController
    }
}

function Test-ADConnection {
    param (
        [string[]]$ADDomainControllers,
        [hashtable]$PortsToCheck
    )
    $results = @()

    foreach ($ADDomainController in $ADDomainControllers) {
        # DNS resolution test
        $results += Test-DnsResolution -ADDomainController $ADDomainController

        # Kerberos authentication test
        $results += Test-KerberosAuthentication -ADDomainController $ADDomainController

        # Port tests
        foreach ($service in $PortsToCheck.GetEnumerator()) {
            $results += Test-PortConnection -ADDomainController $ADDomainController -Port $service.Value -ServiceName $service.Key
        }

        # Add a separator
        $results += [PSCustomObject]@{
            TestName  = "--------"
            Status    = ""
            TargetDC  = "--------"
        }
    }

    # Count and handle failures
    $failedCount = ($results | Where-Object { $_.Status -eq "KO" -and $_.Status }) | Measure-Object | Select-Object -ExpandProperty Count

    Write-Host "$failedCount tests failed."
    Write-Host ""

    # Output the results table
    $results | Format-Table -AutoSize

    if ($failedCount -gt 0) {
        exit 1
    }
}


# Discover all domain controllers in the current domain
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
if ($domain -and $domain -ne 'WORKGROUP') {
    $domainControllers = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers
    $dcNames = $domainControllers | ForEach-Object { $_.Name }

    # Run the tests and display results
    Test-ADConnection -ADDomainControllers $dcNames -PortsToCheck $portsToCheck
} else {
    Write-Host "This machine is not part of a domain."
}
