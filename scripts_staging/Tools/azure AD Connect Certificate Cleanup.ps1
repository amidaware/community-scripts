<#
.TITLE
    AD Connect Certificate Cleanup

.DESCRIPTION
    This script deletes all certificates issued by the Microsoft PolicyKeyService Certificate Authority 
    except for the one with the latest expiration date, and then restarts the AD Connect service (ADSync).
    They are safe to delete.
             
.NOTE
    Author: SAN
    Date: 19.11.24
    Usefull Links:
        https://learn.microsoft.com/en-us/answers/questions/314565/adfs-multiple-certificates-from-microsoft-policyke
        https://learn.microsoft.com/en-us/answers/questions/846864/why-generates-a-lot-of-certificate-in-my-azure-ad
    #public

.CHANGELOG
    
    
#>

# Define the AD Connect service name
$serviceName = "ADSync"

# Check if the AD Connect service is running
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service -eq $null) {
    Write-Host "AD Connect service is not installed on this machine."
    exit
}

if ($service.Status -ne 'Running') {
    Write-Host "AD Connect service is not running. Aborting script."
    exit
}

Write-Host "AD Connect service is running. Proceeding with certificate cleanup."

# Get all certificates from the Microsoft PolicyKeyService Certificate Authority
$certificates = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Issuer -like "*Microsoft PolicyKeyService Certificate Authority*" }

if (-not $certificates) {
    Write-Host "No certificates found for Microsoft PolicyKeyService Certificate Authority."
    exit
}

# Sort certificates by expiry date, descending
$sortedCertificates = $certificates | Sort-Object -Property NotAfter -Descending

# Ensure sortedCertificates is not empty
if ($sortedCertificates.Count -eq 0) {
    Write-Host "No certificates available after sorting. Aborting script."
    exit
}

# The certificate with the biggest expiry date (first one after sorting)
$latestCert = $sortedCertificates[0]

# Remove all certificates except the one with the biggest expiry date
foreach ($cert in $sortedCertificates) {
    if ($cert.Thumbprint -ne $latestCert.Thumbprint) {
        Write-Host "Deleting certificate with thumbprint: $($cert.Thumbprint)"
        try {
            Remove-Item -Path $cert.PSPath -Force
        } catch {
            Write-Host "Error deleting certificate: $($_.Exception.Message)"
        }
    }
}

Write-Host "Deletion complete. Only the certificate with the biggest expiry date remains."

# Restart the AD Connect service
Write-Host "Restarting the AD Connect service..."
Restart-Service -Name $serviceName -Force

Write-Host "AD Connect service has been restarted."
