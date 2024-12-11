<#
.SYNOPSIS
    This PowerShell script performs various checks on an Exchange server and reports status information.

.DESCRIPTION
    This script combines multiple functions to check the health and status of an Exchange server. 
    It checks the submission queue, MAPI connectivity, mailbox databases, DAG index state, and certificate expiration.

.NOTES
    Author: SAN
    Date: 24.04.24
    #public

.CHANGELOG
    23.10.24 SAN Bug fix on the counter
    11.12.24 SAN Code cleanup

#>


$ExchangeServices = Get-Service | Where-Object { $_.DisplayName -like "Microsoft Exchange*" }

if ($ExchangeServices -eq $null) {
    Write-Host "No Exchange services found. Exiting."
    exit 0
} else {
    Write-Host "Exchange services found."
}

# Add Exchange PowerShell Snapin
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn

function CheckQueue {
    $warningThreshold = 500
    $criticalThreshold = 1000

    $queueCount = (Get-Queue -Server $(hostname) -Filter {Identity -eq "Submission"}).MessageCount

    if ($queueCount -eq $null) {
        Write-Host "CRITICAL: Unable to retrieve Submission Queue count."
        return 2
    } elseif ($queueCount -ge $criticalThreshold) {
        Write-Host "CRITICAL: Submission Queue count is $queueCount"
        return 2
    } elseif ($queueCount -ge $warningThreshold) {
        Write-Host "WARNING: Submission Queue count is $queueCount"
        return 1
    } else {
        Write-Host "OK: Submission Queue count is $queueCount"
        return 0
    }
}

function CheckMAPIs {
    $exitCode = 0
    $resultOK = ""
    $resultKO = ""

    Get-MailboxDatabase | Where-Object {$_.Server -match $(hostname.exe)} | ForEach-Object {
        $testResult = Test-MapiConnectivity -Database $_
        if (($testResult.Result -notmatch "Success") -and ($testResult.Result -notmatch "ussite")) {
            $exitCode = 2
            $resultKO += " $($_.Name)"
        } else {
            $resultOK += " $($_.Name)"
        }
    }

    if ($exitCode -eq 0) {
        Write-Host "OK: MAPI databases: $resultOK"
    } else {
        Write-Host "KO: MAPI databases: KO: $resultKO OK: $resultOK"
    }

    return $exitCode
}

function CheckDatabases {
    $statusCode = 0
    $statusMessage = ""

    ForEach ($db in Get-MailboxDatabase -Server $(hostname)) {
        $dbStatus = Get-MailboxDatabaseCopyStatus -Identity "$($db.Name)\$(hostname)"

        foreach ($status in $dbStatus) {
            if ($status.Status -ne "Mounted" -and $status.Status -ne "Healthy") {
                $statusCode = 2
                if ($statusMessage) {
                    $statusMessage += ", "
                }
                $statusMessage += "$($status.Name) is $($status.Status)"
            }
        }
    }

    if ($statusCode -eq 0) {
        Write-Host "OK: All Mailbox Databases are mounted and healthy."
    } else {
        Write-Host "KO: $statusMessage"
    }

    return $statusCode
}


function CheckIndexState {
    $exitCode = 0

    foreach ($index in Get-MailboxDatabaseCopyStatus) {
        if ($index.ContentIndexState -eq "NotApplicable") {
            Write-Host "OK: Index state not applicable."
        } elseif ($index.ContentIndexState -ne "Healthy") {
            $exitCode = 2
            break
        }
    }

    if ($exitCode -eq 2) {
        Write-Host "CRITICAL: Index state error."
    } else {
        Write-Host "OK: Index state is healthy."
    }

    return $exitCode
}

function CheckCertValidity {
    $validCert = (Get-ExchangeCertificate | Where-Object {$_.Services -match "IIS" -and $_.Status -match "Valid" -and $_.IsSelfSigned -eq $False}).NotAfter.AddDays(-30)

    if ((Get-Date) -gt $validCert) {
        Write-Host "CRITICAL: The Exchange certificate expires in less than 30 days."
        return 2
    } else {
        Write-Host "OK: Exchange certificate is valid."
        return 0
    }
}

# Main Script

function GetStatus {
    param (
        [scriptblock]$CheckFunction
    )
    
    return & $CheckFunction
}

$queueStatus = GetStatus { CheckQueue }
$mapiStatus = GetStatus { CheckMAPIs }
$dbStatus = GetStatus { CheckDatabases }
$indexStatus = GetStatus { CheckIndexState }
$certStatus = GetStatus { CheckCertValidity }

# Collect all status codes into an array of integers
$statusArray = @($queueStatus, $mapiStatus, $dbStatus, $indexStatus, $certStatus)

# Calculate the maximum status
$maxStatus = $statusArray | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

# Output the final status
Write-Host "Final Exit Code: $maxStatus"

# Ensure that $maxStatus is an integer before exiting
$host.SetShouldExit([int]$maxStatus)
exit [int]$maxStatus