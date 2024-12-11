<#
.SYNOPSIS
    Display information about certificates in specified stores and optionally delete expired certificates.

.DESCRIPTION
    This script retrieves certificates from specified certificate stores, displays information about each certificate, and categorizes them based on their expiration status.
    If the script is run with the `-DeleteExpired` parameter, it will also delete certificates that have already expired.

.PARAMETER DeleteExpired
    If present, the script will delete certificates that have already expired.

.PARAMETER OutputAll
    If present, the output will be more verbose.

.EXEMPLE
    -DeleteExpired 
    -OutputAll
    WARN_THRESHOLD_DAYS=20
    ERROR_THRESHOLD_DAYS=2
    
.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    29.08.24 SAN Display the full list if none is warn or error, Made a lot of variables for future proofing
    04.09.2024 SAN Problems corrections
    30.09.2024 SAN changed outputs layouts
    11.12.24 SAN added errorThresholdDays to help change the status when close to expiry, moved threshold to env

.TODO
    Make the output messages more readable
    move all flags and var to env

#>

# Get values from environment variables, defaulting if unset
$warnThresholdDays = [int](if ($env:WARN_THRESHOLD_DAYS) { $env:WARN_THRESHOLD_DAYS } else { 20 })
$errorThresholdDays = [int](if ($env:ERROR_THRESHOLD_DAYS) { $env:ERROR_THRESHOLD_DAYS } else { 5 })

# Configuration Variables
$certificateStores = @("Cert:\LocalMachine\My", "Cert:\LocalMachine\WebHosting", "Cert:\LocalMachine\Remote Desktop")
$excludeByName = @()
$excludeByThumbprint = @()
$exitCodeSuccess = 0
$exitCodeWarning = 1
$exitCodeError = 2

# Initialize warn and error counters
$global:warnCount = 0
$global:errorCount = 0

# Check if -DeleteExpired and -OutputAll parameters are present
$deleteExpired = $false
$outputAll = $false
if ($args -contains "-DeleteExpired") {
    $deleteExpired = $true
}
if ($args -contains "-OutputAll") {
    $outputAll = $true
}

# Function to display certificate information and categorize
function DisplayCertificateInfoAndCategorize($cert, $deleteExpired, $outputAll) {
    # Skip excluded certificates
    if ($excludeByName -contains $cert.FriendlyName -or $excludeByThumbprint -contains $cert.Thumbprint) {
        return
    }

    # Check if Subject and Issuer are the same (self-signed)
    if ($cert.Subject -eq $cert.Issuer) {
        return
    }

    $today = Get-Date
    $daysToExpiration = ($cert.NotAfter - $today).Days

    # Display certificate info if expiration is within the threshold or if -OutputAll is true
    if ($daysToExpiration -le $warnThresholdDays -or $outputAll) {
        Write-Host "Certificate Details:"
        Write-Host "--------------------"
        Write-Host "Path           : $($cert.PSPath)"
        Write-Host "Subject        : $($cert.Subject)"
        Write-Host "Issuer         : $($cert.Issuer)"
        Write-Host "Expiration     : $($cert.NotAfter)"
        
        # Conditionally display Friendly Name
        if (-not [string]::IsNullOrEmpty($cert.FriendlyName)) {
            Write-Host "Friendly Name  : $($cert.FriendlyName)"
        }

        Write-Host "Thumbprint     : $($cert.Thumbprint)"

        if ($daysToExpiration -gt 0) {
            if ($daysToExpiration -le $warnThresholdDays) {
                Write-Host "Status         : Warn (Expires in $daysToExpiration days)"
                $global:warnCount++
            } else {
                Write-Host "Status         : Valid (Expires in $daysToExpiration days)"
            }
        } else {
            if ($daysToExpiration -le -$errorThresholdDays) {
                Write-Host "Status         : Error (Expired for more than $errorThresholdDays days)"
                $global:errorCount++
            } else {
                Write-Host "Status         : Error (Expired $(-$daysToExpiration) days ago)"
            }

            if ($deleteExpired -eq $true) {
                Write-Host "Deleting expired certificate..."
                Remove-Item -Path $cert.PSPath
            } else {
                Write-Host "Run me with -DeleteExpired to remove this cert"
            }
        }

        Write-Host "-----------------------------"
    }
}

# Function to handle specific exceptions
function HandleException($exception) {
    if ($exception.Exception -is [System.UnauthorizedAccessException]) {
        Write-Host "Access Denied: Cannot access the certificate store. Please run the script with elevated privileges."
    } else {
        Write-Host "An error occurred: $($exception.Exception.Message)"
    }
}

# Main script logic
foreach ($storePath in $certificateStores) {
    # Only display "Checking" message if -OutputAll is called
    if ($outputAll) {
        Write-Host "Checking certificates in ${storePath}..."
    }

    try {
        $certificates = Get-ChildItem -Path $storePath
        if ($null -ne $certificates -and $certificates.Count -gt 0) {
            if ($outputAll) {
                Write-Host "Certificates found in ${storePath}:"
                Write-Host "-----------------------------"
            }
            foreach ($cert in $certificates) {
                DisplayCertificateInfoAndCategorize $cert $deleteExpired $outputAll
            }
        } elseif ($outputAll) {
            Write-Host "No certificates found in ${storePath}."
            Write-Host "-----------------------------"
        }
    } catch {
        HandleException $_
    }
}

# Display messages based on warn and error counts
if ($global:errorCount -gt 0) {
    Write-Host "There are $($global:errorCount) certificate(s) in error status."
    $host.SetShouldExit($exitCodeError)
    exit $exitCodeError
}

if ($global:warnCount -gt 0) {
    Write-Host "There are $($global:warnCount) certificate(s) in warning status."
    $host.SetShouldExit($exitCodeWarning)
    exit $exitCodeWarning
}

# If no errors or warnings were found and -OutputAll was not used
if ($global:warnCount -eq 0 -and $global:errorCount -eq 0 -and -not $outputAll) {
    # Calculate the next expiry date
    $nextExpiryDays = [int]::MaxValue # Start with a high number
    foreach ($storePath in $certificateStores) {
        try {
            $certificates = Get-ChildItem -Path $storePath
            if ($null -ne $certificates -and $certificates.Count -gt 0) {
                foreach ($cert in $certificates) {
                    $daysToExpiration = ($cert.NotAfter - (Get-Date)).Days
                    if ($daysToExpiration -gt 0 -and $daysToExpiration -lt $nextExpiryDays) {
                        $nextExpiryDays = $daysToExpiration
                    }
                }
            }
        } catch {
            HandleException $_
        }
    }
    Write-Host "OK Next expiry in $nextExpiryDays days."
    $host.SetShouldExit($exitCodeSuccess)
    exit $exitCodeSuccess
}

# If OutputAll was used, we need to end the script with a success code without additional output
if ($outputAll) {
    $host.SetShouldExit($exitCodeSuccess)
    exit $exitCodeSuccess
}
