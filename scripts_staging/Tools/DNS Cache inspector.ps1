<#
.SYNOPSIS
This script inspects and displays the Windows DNS client cache entries using either
`Get-DnsClientCache` (preferred) or by parsing the output of `ipconfig /displaydns` (fallback).

.DESCRIPTION
The script queries the local DNS client cache to show cached domain entries, record types,
record data, and TTL values. If the PowerShell cmdlet `Get-DnsClientCache` is unavailable,
the script falls back to parsing the `ipconfig /displaydns` output.

The script supports filtering cache entries based on a target string provided
through the environment variable `DNS_TARGET`.  
If no environment variable is set, it defaults to `*` (all entries).

.EXAMPLE
    DNS_TARGET=*.microsoft.com

.NOTE
    Author: SAN
    Date: 01.10.25
    #Public

.CHANGELOG

#>

# Get filter target from environment variable
$Filter = $env:DNS_TARGET
if ([string]::IsNullOrWhiteSpace($Filter)) {
    $Filter = '*'
}

Write-Host ''
Write-Host '--- Windows DNS Cache Inspector ---'
Write-Host 'Target filter:' $Filter
Write-Host ''

# Try Get-DnsClientCache first
try {
    $results = Get-DnsClientCache -ErrorAction Stop | Where-Object {
        ($_.Name -like $Filter) -or ($_.RecordData -like $Filter) -or ($_.RecordType -like $Filter)
    } | Select-Object Name, Entry, RecordType, RecordData,
                      @{Name='TTL';Expression={$_.TimeToLive}},
                      Section, Status
} catch {
    $results = @()
}

# Fallback to ipconfig /displaydns
if (-not $results -or $results.Count -eq 0) {
    Write-Host 'No results from Get-DnsClientCache, falling back to ipconfig parsing...'

    $raw = ipconfig /displaydns 2>&1
    $blocks = -split ($raw -join "`n"), "`n`r?`n"

    $results = @()
    foreach ($b in $blocks) {
        $lines = $b -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        if ($lines.Count -eq 0) { continue }

        $entry = [PSCustomObject]@{
            Name           = $null
            RecordType     = $null
            RecordData     = $null
            TTL            = $null
            CacheEntryType = $null
            Section        = $null
        }

        foreach ($line in $lines) {
            if ($line -match 'Record Name\s*:\s*(.+)$') { $entry.Name = $matches[1].Trim() }
            elseif ($line -match 'Record Type\s*:\s*(.+)$') { $entry.RecordType = $matches[1].Trim() }
            elseif ($line -match 'Time To Live\s*:\s*(\d+)') { $entry.TTL = [int]$matches[1] }
            elseif ($line -match 'Data:\s*(.+)$') { $entry.RecordData = $matches[1].Trim() }
            elseif ($line -match 'A\s+Record\s*:\s*(.+)$') { $entry.RecordData = $matches[1].Trim() }
            elseif ($line -match 'Cache Entry Type\s*:\s*(.+)$') { $entry.CacheEntryType = $matches[1].Trim() }
            elseif ($line -match 'Section\s*:\s*(.+)$') { $entry.Section = $matches[1].Trim() }
        }

        if ($entry.Name) { $results += $entry }
    }

    if ($Filter -ne '*') {
        $results = $results | Where-Object {
            ($_.Name -like $Filter) -or ($_.RecordData -like $Filter) -or ($_.RecordType -like $Filter)
        }
    }
}

# Output
$results = $results | Sort-Object Name
Write-Host ''
Write-Host 'Entries found:' $results.Count
Write-Host ''

if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
    Write-Host ''
    Write-Host 'Match found — exiting with code 1.'
    exit 1
} else {
    Write-Host 'No DNS cache entries found.'
    exit 0
}
