<#
.SYNOPSIS
    This script checks for available Windows updates and alerts if any updates are older than a specified threshold.

.DESCRIPTION
    The script retrieves a list of available updates using the PSWindowsUpdate module. It then checks 
    whether any updates have a release date older than the specified threshold in days and provides an alert 
    if such updates are found.

.NOTES
    Author: SAN
    Date: 25.03.2025
    #public
    Dependencies: 
        PSWindowsUpdate module

.CHANGELOG
    SAN 25.03.2025 Initial version of the script to check updates older than a specified threshold.

.TODO
    Add filters to ignore updates in env
    
#>

$ThresholdDays = $env:ThresholdDays
if (-not $ThresholdDays) {
    $ThresholdDays = 90
}

$CurrentDate = Get-Date
$AgeLimit = $CurrentDate.AddDays(-$ThresholdDays)

try {
    $updates = Get-WindowsUpdate -ErrorAction Stop
} catch {
    Write-Host "KO: An error occurred while fetching the updates: $_"
    exit 1
}

if ($updates.Count -eq 0) {
    Write-Host "OK: No updates found."
} else {
    $updates | ForEach-Object {
        Write-Host "$($_.LastDeploymentChangeTime) | KB: $($_.KBArticleIDs) | $($_.Title)"
    }

    $OldUpdates = $updates | Where-Object { $_.LastDeploymentChangeTime -lt $AgeLimit }

    if ($OldUpdates) {
        Write-Host "KO: The following updates are older than $ThresholdDays days:"
        $OldUpdates | Select-Object Title, KBArticleIDs, LastDeploymentChangeTime | Format-Table -AutoSize
        exit 1
    } else {
        Write-Host "OK: All available updates are within the last $ThresholdDays days."
    }
}
