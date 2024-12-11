<#
.SYNOPSIS
   Checks the size of MDF and LDF files and returns an exit code based on file size.

.DESCRIPTION
   This script checks the size of the specified MDF file (e.g., SQL Server database file) and compares it against a defined size threshold. If the file size exceeds the threshold (80MB in this case), it outputs a critical message and returns an exit code of 1. If the file size is within the threshold, it returns an exit code of 0. If the file does not exist, the script skips the check and returns an exit code of 0.
   If the MDF file becomes too large, especially in the context of an RDS (Remote Desktop Services) server, it can reach a critical size and prevent the RDS server from functioning properly. This can cause system errors or failures related to the database, which might lead to disruptions in RDS operations.

.NOTES
	Author: SAN
    #public

.CHANGELOG
    
#>

$MDFFilePath = 'C:\Windows\rdcbDb\Rdcms.mdf'
$fileSizeThreshold = 80MB

try {
    if (!(Test-Path $MDFFilePath -PathType 'Leaf')) {
        Write-Output "File not found. Skipping file check."
        exit 0
    }

    $mdfSize = (Get-Item $MDFFilePath).Length

    if ($mdfSize -gt $fileSizeThreshold) {
        Write-Output "File size exceeded the threshold. MDF Size: $($mdfSize / 1MB) MB."
        Write-Output "Critical the RDS server is about to stop"
        Write-Output "Check the links bellow for more informations:"
        Write-Output "https://learn.microsoft.com/fr-fr/sql/relational-databases/logs/troubleshoot-a-full-transaction-log-sql-server-error-9002?view=sql-server-ver16"
        Write-Output "https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/esent-event-327-326"
        exit 1

    }
    else {
        Write-Output "File size is within the threshold. MDF Size: $($mdfSize / 1MB) MB."
        exit 0
    }
}
catch {
    Write-Output "An error occurred: $($_.Exception.Message)"
    exit 1
}