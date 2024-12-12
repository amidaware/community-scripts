<#
.SYNOPSIS
    This script manages SSL certificates for IIS, RDS Gateway, and common Windows certificate stores. It identifies, lists, and optionally deletes certificates based on thumbprints.

.DESCRIPTION
    The script performs the following tasks:
    - Imports necessary modules (WebAdministration for IIS, RemoteDesktopServices for RDS).
    - Lists SSL certificates bound to IIS sites.
    - Retrieves the SSL certificate thumbprint for an RDS Gateway (if applicable).
    - Lists all self-signed certificates across common certificate stores.
    - Identifies and lists certificates that are not already listed by other functions.
    - Deletes certificates using an environment variable (DeleteThumbprint) if set.

.EXEMPLE
    DeleteThumbprint=DFDF45DF45F8DFD92QA

.NOTES
    Author:SAN
    Date: 15.08.24
    #public

.TODO
    Add exchange section
    Add CA to the reports.

#>


# Import the necessary modules
$importIIS = $false
$importRDS = $false

try {
    Import-Module WebAdministration -ErrorAction Stop
    $importIIS = $true
} catch {
    Write-Host "Failed to import WebAdministration module. IIS-related functions will not run."
}

try {
    Import-Module RemoteDesktopServices -ErrorAction Stop
    $importRDS = $true
} catch {
    Write-Host "Failed to import RemoteDesktopServices module. RDS-related functions will not run."
}

# List of thumbprints already found
$global:listedThumbprints = @()

# Function to add thumbprints to the list
function Add-ToListedThumbprints {
    param (
        [string]$Thumbprint
    )
    if ($Thumbprint -notin $global:listedThumbprints) {
        $global:listedThumbprints += $Thumbprint
    }
}

# Function to get certificate details from all known stores
function Get-CertificateDetails {
    param (
        [string]$Thumbprint
    )

    $stores = Get-AllCertificateStores
    
    foreach ($store in $stores) {
        try {
            $certs = Get-ChildItem -Path $store -ErrorAction SilentlyContinue
            $cert = $certs | Where-Object { $_.Thumbprint -eq $Thumbprint }
            if ($cert) {
                return @{
                    Certificate = $cert
                    StorePath   = $store
                }
            }
        } catch {
            Write-Host "Failed to access certificate store: $store"
        }
    }

    return $null
}

# Function to get certificate details given its thumbprint
function Get-CertificateDetailsByThumbprint {
    param (
        [string]$Thumbprint
    )
    
    $result = Get-CertificateDetails -Thumbprint $Thumbprint
    if ($result) {
        return [PSCustomObject]@{
            "Thumbprint"       = $result.Certificate.Thumbprint
            "Subject"          = $result.Certificate.Subject
            "ExpirationDate"   = $result.Certificate.NotAfter
        }
    } else {
        Write-Host "Certificate with Thumbprint $Thumbprint not found in any store."
        return $null
    }
}

# Function to list IIS SSL certificate thumbprints
function List-IIS-SSL-Thumbprints {
    $results = @()
    $sites = Get-Website

    foreach ($site in $sites) {
        foreach ($binding in $site.Bindings.Collection) {
            if ($binding.Protocol -eq "https") {
                $sslCertHash = $binding.CertificateHash
                $thumbprint = -join ($sslCertHash | ForEach-Object { "{0:X2}" -f $_ })

                $certDetails = Get-CertificateDetailsByThumbprint -Thumbprint $thumbprint

                # Add to listed thumbprints
                Add-ToListedThumbprints -Thumbprint $thumbprint

                $results += [PSCustomObject]@{
                    "Thumbprint"     = $thumbprint
                    "Subject"        = $certDetails.Subject
                    "Expiration Date"= $certDetails.ExpirationDate
                    "IIS Site"       = $site.Name
                    "Binding Info"   = $binding.BindingInformation
                }
            }
        }
    }

    $results | Format-Table -AutoSize
}

# Function to get RDS Gateway SSL certificate thumbprint
function Get-RDGatewaySSLCertificateThumbprint {
    param (
        [string]$Path = 'RDS:\GatewayServer\SSLCertificate\Thumbprint'
    )

    try {
        $thumbprintValue = (Get-Item -Path $Path).CurrentValue
        
        if ([string]::IsNullOrWhiteSpace($thumbprintValue)) {
            Write-Host "The SSL certificate thumbprint set for RD Gateway is empty or not set."
        } else {
            $certDetails = Get-CertificateDetailsByThumbprint -Thumbprint $thumbprintValue

            # Add to listed thumbprints
            Add-ToListedThumbprints -Thumbprint $thumbprintValue

            [PSCustomObject]@{
                "Thumbprint"                         = $thumbprintValue
                "Subject"                            = $certDetails.Subject
                "Expiration Date"                    = $certDetails.ExpirationDate
            } | Format-Table -AutoSize
        }
    }
    catch {
        Write-Host "An error occurred while retrieving the SSL certificate thumbprint or the RDS Gateway role is not installed."
    }
}

# Function to get all common certificate stores
function Get-AllCertificateStores {
    return @(
        "Cert:\LocalMachine\My",
        "Cert:\LocalMachine\WebHosting",        # Web hosting store, if applicable
        "Cert:\LocalMachine\RDS\GatewayServer", # RDS Gateway Server, if applicable
        "Cert:\LocalMachine\RDS\ConnectionBroker", # RDS Connection Broker, if applicable
        "Cert:\LocalMachine\Remote Desktop"
    )
}

# Function to list certificates that are self-signed
function List-SelfSignedCertificates {
    $results = @()
    Write-Host "Listing Self-Signed Certificates:"

    $stores = Get-AllCertificateStores

    foreach ($store in $stores) {
        try {
            $certs = Get-ChildItem -Path $store -ErrorAction SilentlyContinue
            foreach ($cert in $certs) {
                if ($cert.Issuer -eq $cert.Subject) {  # Self-signed certificates
                    $thumbprint = $cert.Thumbprint

                    # Add to listed thumbprints
                    Add-ToListedThumbprints -Thumbprint $thumbprint

                    $results += [PSCustomObject]@{
                        "Thumbprint"     = $thumbprint
                        "Subject"        = $cert.Subject
                        "Expiration Date"= $cert.NotAfter
                        "Store Location" = $store
                    }
                }
            }
        } catch {
            Write-Host "Failed to access certificate store: $store"
        }
    }

    $results | Format-Table -AutoSize
}

# Function to list certificates that are not listed by other functions
function List-UnlistedCertificates {
    $results = @()
    Write-Host "Listing Unlisted Certificates:"

    $stores = Get-AllCertificateStores

    foreach ($store in $stores) {
        try {
            $certs = Get-ChildItem -Path $store -ErrorAction SilentlyContinue
            foreach ($cert in $certs) {
                $thumbprint = $cert.Thumbprint

                if ($thumbprint -notin $global:listedThumbprints) {
                    $results += [PSCustomObject]@{
                        "Thumbprint"     = $thumbprint
                        "Store Location" = $store
                        "Subject"        = $cert.Subject
                        "Expiration Date"= $cert.NotAfter
                    }
                }
            }
        } catch {
            Write-Host "Failed to access certificate store: $store"
        }
    }

    $results | Format-Table -AutoSize
}

# Function to delete certificates by thumbprint based on an environment variable
function Delete-CertificateByThumbprint {
    $thumbprintToDelete = $env:DeleteThumbprint

    if ([string]::IsNullOrWhiteSpace($thumbprintToDelete)) {
        Write-Host "Environment variable 'DeleteThumbprint' is not set or empty."
        return
    }

    Write-Host "Attempting to delete certificates with Thumbprint: $thumbprintToDelete"
    $stores = Get-AllCertificateStores

    foreach ($store in $stores) {
        try {
            $certs = Get-ChildItem -Path $store -ErrorAction SilentlyContinue
            foreach ($cert in $certs) {
                if ($cert.Thumbprint -eq $thumbprintToDelete) {
                    Write-Host "Deleting certificate with Thumbprint: $thumbprintToDelete from $store"
                    Remove-Item -Path $cert.PSPath -Force
                }
            }
        } catch {
            Write-Host "Failed to delete certificate from store: $store"
        }
    }
}

# Main script execution
if ($importIIS) {
    Write-Host "Listing IIS SSL Thumbprints:"
    List-IIS-SSL-Thumbprints
}

if ($importRDS) {
    Write-Host "Getting RDS Gateway SSL Certificate Thumbprint:"
    Get-RDGatewaySSLCertificateThumbprint
}

# List self-signed certificates
List-SelfSignedCertificates

# List certificates that were not listed by other functions
List-UnlistedCertificates

# Attempt to delete certificates based on the DeleteThumbprint environment variable
Delete-CertificateByThumbprint