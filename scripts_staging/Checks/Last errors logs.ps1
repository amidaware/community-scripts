<#
.SYNOPSIS
    This script retrieves and processes error events from the Windows Event Log within the last 48 and 12 hours.

.DESCRIPTION
    This script is useful for monitoring and alerting on error events in the Windows Event Log.
    The script processes error logs from the 'System' log only, only critical errors are counted and displayed.

    1. Retrieves the last 20 error events from the 'System' log in the last 48 hours, excluding specified event IDs.
    2. Counts and displays the number of error events found in the last 48 hours (after filtering out ignored events).
    3. Retrieves error events from the last 12 hours and checks if there are 4 or more errors.
    4. If 4 or more errors are found in the last 12 hours, the script exits with an error code (1).
    5. If fewer than 4 errors are found, the script exits with a success code (0).

.EXEMPLE
    debug=true
    FILTER_ID=1111,22222,3333
    FILTER_KEYWORD=keyword1,keyword2

.NOTES
    Author: SAN
    Date: 24.10.2024
    #public

    10016 safe to ignore
    https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/event-10016-logged-when-accessing-dcom
    36874 to ignore
    Fixing the issue would be more dangerous than leaving it be it would require blocking tls 1.2 and forcing 1.1 with unsafe cyphers and loosing connection to devices that do not support 1.1

.CHANGELOG
    04.12.24 SAN added id to ignore in comma separeted variable
    12.12.24 SAN adding keyword filters, added filter addition via env var

.TODO
    Set 20 Error Events and 48 hours in vars same for 4 and 12
    Re-thing the thresholds to add info warn error limits

#>

$defaultEventIds = @(10016,36874)
$defaultKeywords = @("gupdate","anotherkeyword")

$debug = [System.Environment]::GetEnvironmentVariable("DEBUG")
$filterIdEnv = [System.Environment]::GetEnvironmentVariable("FILTER_ID")
$filterKeywordEnv = [System.Environment]::GetEnvironmentVariable("FILTER_KEYWORD")

$ignoredEventIds = if ($filterIdEnv) { 
    $filterIdEnv.Split(",") + $defaultEventIds 
} else { 
    $defaultEventIds 
}

$ignoredKeywords = if ($filterKeywordEnv) { 
    $filterKeywordEnv.Split(",") + $defaultKeywords 
} else { 
    $defaultKeywords 
}

$start48h = (Get-Date).AddHours(-48)
$start12h = (Get-Date).AddHours(-12)

$allErrors48h = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$start48h} -ErrorAction SilentlyContinue

$eventsWithIdFilter = $allErrors48h | Where-Object { $ignoredEventIds -contains $_.Id.ToString() }

$eventsWithKeywordFilter = $allErrors48h | Where-Object {
    $eventData = $_.Properties -join " "
    $eventData += " " + $_.Message
    $keywordMatches = $false
    $ignoredKeywords | ForEach-Object {
        $keyword = $_.Trim()
        if ($eventData -match "(?i)\b$($keyword)\b") {
            $keywordMatches = $true
        }
    }
    $keywordMatches
}

if ($debug -eq "true") {
    Write-Output "DEBUG: Filtering events with the following parameters:"
    Write-Output "DEBUG: Filtered Event IDs: $ignoredEventIds"
    Write-Output "DEBUG: Filtered Keywords: $ignoredKeywords"

    if ($eventsWithIdFilter.Count -gt 0) {
        Write-Output "Filtered Events by Event ID in the last 48 hours:"
        $eventsWithIdFilter | ForEach-Object {
            Write-Output "TimeCreated: $($_.TimeCreated)"
            Write-Output "Event ID: $($_.Id)"
            Write-Output "Message: $($_.Message)"
            Write-Output "----------------------------------------"
        }
    } else {
        Write-Output "No events found matching the specified Event IDs in the last 48 hours."
    }

    if ($eventsWithKeywordFilter.Count -gt 0) {
        Write-Output "Filtered Events by Keyword in the last 48 hours:"
        $eventsWithKeywordFilter | ForEach-Object {
            Write-Output "TimeCreated: $($_.TimeCreated)"
            Write-Output "Event ID: $($_.Id)"
            Write-Output "Message: $($_.Message)"
            Write-Output "----------------------------------------"
        }
    } else {
        Write-Output "No events found matching the specified Keywords in the last 48 hours."
    }
}

$remainingErrors48h = $allErrors48h | Where-Object {
    $eventIdMatches = $ignoredEventIds -contains $_.Id.ToString()
    $eventData = $_.Properties -join " "
    $eventData += " " + $_.Message
    $keywordMatches = $false
    $ignoredKeywords | ForEach-Object {
        $keyword = $_.Trim()
        if ($eventData -match "(?i)\b$($keyword)\b") {
            $keywordMatches = $true
        }
    }
    if ($eventIdMatches -or $keywordMatches) {
        $false
    } else {
        $true
    }
}

if ($remainingErrors48h.Count -gt 0) {
    Write-Output "Remaining Error Events in the last 48 hours (after filtering out ignored Event IDs and Keywords):"
    $remainingErrors48h | ForEach-Object {
        Write-Output "TimeCreated: $($_.TimeCreated)"
        Write-Output "Event ID: $($_.Id)"
        Write-Output "Message: $($_.Message)"
        Write-Output "----------------------------------------"
    }
}

$errors12h = $remainingErrors48h | Where-Object { $_.TimeCreated -gt $start12h }

if ($errors12h.Count -ge 4) {
    Write-Output "Error: 4 or more error events found in the last 12 hours."
    Write-Output "Error Events in the last 12 hours (excluding ignored event IDs and keywords):"
    $errors12h | ForEach-Object {
        Write-Output "TimeCreated: $($_.TimeCreated)"
        Write-Output "Event ID: $($_.Id)"
        Write-Output "Message: $($_.Message)"
        Write-Output "----------------------------------------"
    }
    exit 1
} else {
    if ($errors12h.Count -eq 0) {
        Write-Output "OK: No error events found in the last 12 hours."
    } else {
        Write-Output "OK: Less than 4 error events found in the last 12 hours."
    }
    exit 0
}
