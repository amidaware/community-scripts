<#
.SYNOPSIS
Configures the RD Gateway SSL certificate and checks settings for the "win-acme" task.

.DESCRIPTION
This script checks if the RD Gateway service and a task with "win-acme" in its name exist.
It also verifies and updates the "settings.json" file to ensure PrivateKeyExportable is set to true.
If all conditions are met, it imports a new SSL certificate to the RD Gateway.
Optionally, it can run the win-acme (wacs.exe) command to install a Let's Encrypt certificate.

.PARAMETER settingsJsonPath
Specifies the path to the settings.json file. Default is "C:\tools\win-acme\settings.json". the default location of instalation of Win-Acme by chocolatey.

.PARAMETER InstallLE
Specifies whether to install a Let's Encrypt certificate using win-acme. Default is false.

.PARAMETER RDSURL
Specifies what url will be set in the bindings when installLE is called

.PARAMETER ForceReplaceCertRDS
ignore the fail-safe checks and force the replacement of rds certs and restart the gateway

.EXEMPLE
-settingsJsonPath "C:\tools\win-acme\settings.json"
-RDSURL {{agent.RDSURL}}
-ForceReplaceCertRDS
-InstallLE

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    28/08/24 SAN Added a deletion of old cert when changes happens (this may not be possible with the TODO planned and would require a scraping of the idea)
    02/09/24 SAN Full re-write of the cert management to make it smart, it will not restart the service if no change is needed or fore re-write of the cert and also change logic for deleting old certs
    02/09/24 SAN Legacy Code cleanup 
    02/09/24 SAN added -ForceReplaceCertRDS and a couple of fail-safe
    03/09/24 SAN added choco install to install section
    04/09/24 SAN corrected logic for deployement and force
    07/01/24 SAN changed old cert deletion logic


.TODO
    find a way to call the script from the renew -script process of win-acme
    for referance: C:\tools\win-acme\wacs.exe --source iis --verbose --siteid 1 --commonname $RDSURL --installation iis --installationsiteid 1 --script "C:\tools\win-acme\Scripts\ImportRDGateway.ps1" --scriptparameters '{CertThumbprint}'
    change pathing based on folder for both .json and .exe
    better way than calling iis 0 for the change ? probably possible if called from -script
#>
param (
    [string]$settingsJsonPath = "C:\tools\win-acme\settings.json",
    [switch]$InstallLE,
    [string]$RDSURL,
    [switch]$ForceReplaceCertRDS
)

Function InstallLetEncryptCertificate {
    choco install win-acme
    $wacsCommand = "C:\tools\win-acme\wacs.exe --source iis --siteid 1 --commonname $RDSURL --installation iis --installationsiteid 1"
    Write-Host "Executing command: $wacsCommand"
    try {
        Invoke-Expression $wacsCommand
    } catch {
        Write-Error "Failed to execute win-acme command. Error: $_"
        exit 1
    }
}

Function BindRDSURL {
    if ($RDSURL) {
        Write-Host "Binding RDSURL to HTTPS of the default IIS site..."
        try {
            New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 443 -HostHeader $RDSURL -Protocol "https"
            Write-Host "RDSURL bound to HTTPS of the default IIS site."
        } catch {
            Write-Error "Failed to bind RDSURL. Error: $_"
        }
    } else {
        Write-Warning "RDSURL is not provided. Skipping binding process."
    }
}

Function Get-RDGatewaySSLCertificateThumbprint {
    param (
        [string]$Path = 'RDS:\GatewayServer\SSLCertificate\Thumbprint'
    )

    try {
        $thumbprintValue = (Get-Item -Path $Path).CurrentValue
        if ([string]::IsNullOrWhiteSpace($thumbprintValue)) {
            return $null
        } else {
            return $thumbprintValue
        }
    } catch {
        Write-Error "An error occurred while retrieving the SSL certificate thumbprint: $_"
        return $null
    }
}

function Is-ValidThumbprint {
    param (
        [string]$Thumbprint
    )
    return $Thumbprint -and $Thumbprint.Length -eq 40 -and $Thumbprint -match '^[0-9A-Fa-f]+$'
}

Function Remove-OldLECertificates {

    $stores = @(
        "Cert:\LocalMachine\My",
        "Cert:\LocalMachine\WebHosting",
        "Cert:\LocalMachine\Remote Desktop"
    )

    $certsRemoved = $false

    foreach ($store in $stores) {
        try {
            # Get Let's Encrypt certificates by checking the Issuer or Subject
            $leCerts = Get-ChildItem -Path $store -Recurse | Where-Object { 
                $_.Issuer -like "*Let's Encrypt*" 
            }

            if ($leCerts.Count -le 1) {
                Write-Host "Less than two Let's Encrypt certificates found in $store. No removal required."
            } else {
                # Sort certificates by NotAfter date (ascending) and select the oldest one
                $oldCert = $leCerts | Sort-Object -Property NotAfter | Select-Object -First 1

                if ($oldCert) {
                    Remove-Item -Path $oldCert.PSPath -Confirm:$false
                    Write-Host "Removed oldest Let's Encrypt certificate with thumbprint $($oldCert.Thumbprint) from $store."
                    $certsRemoved = $true
                }
            }
        } catch {
            Write-Error "Failed to remove certificates from $store. Error: $_"
        }
    }

    return $certsRemoved
}


# Check if Get-RDUserSession is available, if not exit with code 0
try {
    $null = Get-RDUserSession -ErrorAction Stop
}
catch {
    if ($_.Exception.Message -match "A Remote Desktop Services deployment does not exist") {
        Write-Output "Remote Desktop Services deployment does not exist. Exiting."
        exit 0
    }
    else {
        Write-Output "An unexpected error occurred while checking for RDS deployment."
        Write-Output "Error: $($_.Exception.Message)"
        exit 0
    }
}

# Check if settings.json file exists
if (-not $InstallLE.IsPresent -and -not (Test-Path $settingsJsonPath)) {
    Write-Host "settings.json not found. EXIT"
    exit 1
}

# Install Let's Encrypt certificate if InstallLE is set to true
if ($InstallLE) {
    if (-not $RDSURL) {
        Write-Error "RDSURL is required when InstallLE is true. Exiting script."
        exit 1
    }

    BindRDSURL
    InstallLetEncryptCertificate
}

# Check if PrivateKeyExportable is set to true in settings.json
$settingsJson = Get-Content -Path $settingsJsonPath -Raw | ConvertFrom-Json
$privateKeyExportable = $settingsJson.Store.CertificateStore.PrivateKeyExportable

if (-not $privateKeyExportable) {
    $settingsJson.Store.CertificateStore.PrivateKeyExportable = $true
    try {
        $settingsJson | ConvertTo-Json | Set-Content -Path $settingsJsonPath
        Write-Host "PrivateKeyExportable set to true in settings.json"
    } catch {
        Write-Error "Failed to update settings.json. Error: $_"
        exit 1
    }
}

# Check if the RD Gateway service exists
$gatewayService = Get-Service -Name TSGateway -ErrorAction SilentlyContinue
# Check if a task with "win-acme" in its name exists
$winAcmeTask = Get-ScheduledTask -TaskName "*win-acme*" -ErrorAction SilentlyContinue

if ($gatewayService -and $winAcmeTask) {
    Import-Module RemoteDesktopServices
    Import-Module WebAdministration

    # Retrieve thumbprints currents 
    $IISCertThumbprint = (Get-ChildItem IIS:SSLBindings)[0].Thumbprint
    $RDSCertThumbprint = Get-RDGatewaySSLCertificateThumbprint

    if (-not $ForceReplaceCertRDS) {
        if ($RDSCertThumbprint -eq $IISCertThumbprint) {
            Write-Host "RDS: $RDSCertThumbprint"
            Write-Host "IIS: $IISCertThumbprint"
            Write-Host "The RD Gateway SSL certificate is already the same as IIS. No replacement needed."
            exit 0
        }
        Write-Host "RDS: $RDSCertThumbprint"
        Write-Host "IIS: $IISCertThumbprint"

        # Validate IIS certificate thumbprint
        if (Is-ValidThumbprint -Thumbprint $IISCertThumbprint) {
            Write-Host "IIS certificate thumbprint $IISCertThumbprint is valid. Continuing."
        } else {
            Write-Error "Invalid IIS certificate thumbprint: $IISCertThumbprint. Exiting script."
            exit 1
        }
    }

    # Retrieve the certificate from the local machine store that matches the specified thumbprint
    $CertInStore = Get-ChildItem -Path Cert:\LocalMachine -Recurse | Where-Object {$_.Thumbprint -eq $IISCertThumbprint} | Sort-Object -Descending | Select-Object -First 1

    if ($CertInStore) {
        try {
            # Check if the certificate is not already in the 'LocalMachine\My' store
            if ($CertInStore.PSPath -notlike "*LocalMachine\My\*") {
                # The certificate is not in the 'My' store, so we will move it there
                $SourceStoreScope = 'LocalMachine'
                $SourceStorename = $CertInStore.PSParentPath.Split("\")[-1]

                Write-Host "Certificate found in '$SourceStorename' store. Moving it to 'LocalMachine\My'."

                # Open the source certificate store (Read-Only)
                $SourceStore = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $SourceStorename, $SourceStoreScope
                $SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

                # Retrieve the certificate from the source store
                $cert = $SourceStore.Certificates | Where-Object {$_.Thumbprint -eq $CertInStore.Thumbprint}

                # Define the destination store ('My') and open it (Read-Write)
                $DestStoreScope = 'LocalMachine'
                $DestStoreName = 'My'
                $DestStore = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $DestStoreName, $DestStoreScope
                $DestStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

                # Add the certificate to the destination store
                $DestStore.Add($cert)
                Write-Host "Certificate successfully added to 'LocalMachine\My'."

                # Close both stores
                $SourceStore.Close()
                $DestStore.Close()

                # Update the $CertInStore variable to reference the newly moved certificate
                $CertInStore = Get-ChildItem -Path Cert:\LocalMachine\My -Recurse | Where-Object {$_.Thumbprint -eq $IISCertThumbprint} | Sort-Object -Descending | Select-Object -First 1
            } else {
                Write-Host "Certificate is already in the 'LocalMachine\My' store."
            }

            # Set the certificate thumbprint in the RD Gateway listener
            Set-Item -Path RDS:\GatewayServer\SSLCertificate\Thumbprint -Value $CertInStore.Thumbprint -ErrorAction Stop
            Write-Host "RD Gateway listener thumbprint set to the new certificate."

            # Restart the Terminal Services Gateway service to apply the new certificate
            Restart-Service TSGateway -Force -ErrorAction Stop
            Write-Host "TSGateway service restarted successfully."

            # Call function to remove old certificates
            $certsRemoved = Remove-OldLECertificates

            # Check if old certificates were removed
            if (-not $certsRemoved) {
                Write-Error "No old certificates $RDSCertThumbprint were removed. Exiting script."
                exit 1
            } else {
                Write-Host "Old certificates removed successfully."
            }

        } catch {
            # Handle any errors that occurred during the process
            Write-Error "Failed to set certificate thumbprint or restart the service. Error: $_"
            exit 1
        }
    } else {
        # Certificate with the specified thumbprint was not found in the certificate store
        Write-Error "Certificate with thumbprint '$IISCertThumbprint' not found in the certificate store."
        exit 1
    }
} elseif (-not $gatewayService) {
    Write-Error "RD Gateway service not found."
} elseif (-not $winAcmeTask) {
    Write-Error "Task with 'win-acme' not found."
}