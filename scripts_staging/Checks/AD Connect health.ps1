<#
.SYNOPSIS
	Check Azure AD Connect Sync.

.DESCRIPTION
	Check Azure AD Connect Sync status and returns output and code.

.PARAMETER Hours
	Hours since the last synchronization.
	Default: 3

.EXEMPLE 
    SYNC_HOURS=6

.NOTES 
	Author:	Juan Granados
    #public

.CHANGELOG
    04.09.2024 SAN Problems corrections
    11.12.24 SAN moved hours to env
#>


# Check if the environment variable is set, otherwise default to 3
$Hours = [int]$env:SYNC_HOURS
if (-not $Hours) {
    $Hours = 3
}

# Check if ADSync module (Azure AD Connect) is installed
if (-not (Get-Module -Name ADSync -ListAvailable)) {
    Write-Host "Azure AD Connect is not installed. Exiting."
    exit 0
}

$Output = ""
$ExitCode = 0

$pingEvents = Get-EventLog -LogName "Application" -Source "Directory Synchronization" -InstanceId 654 -After (Get-Date).AddHours(-$($Hours)) -ErrorAction SilentlyContinue |
    Sort-Object { $_.Time } -Descending
if ($null -ne $pingEvents) {
    $Output = "Latest heart beat event (within last $($Hours) hours). Time $($pingEvents[0].TimeWritten)."
} else {
    $Output = "No ping event found within last $($Hours) hours."
    $ExitCode = 1
}

$ADSyncScheduler = Get-ADSyncScheduler
if (!$ADSyncScheduler.SyncCycleEnabled) {
    $ExitCode = 2
}

if ($ADSyncScheduler.StagingModeEnabled) {
    $Output = "Server is in stand by mode. $($Output)"
} else {
    $Output = "Server is in active mode. $($Output)"
}

if ($ExitCode -eq 0) {
    Write-Host "OK: Azure AD Connect Sync is up and running."
    Write-Host "$($Output)"
} elseif ($ExitCode -eq 1) {
    Write-Host "WARNING: Azure AD Connect Sync is enabled, but not syncing."
    Write-Host "$($Output)"
} elseif ($ExitCode -eq 2) {
    Write-Host "CRITICAL: Azure AD Connect Sync is disabled."
    Write-Host "$($Output)"
}

$host.SetShouldExit($ExitCode)
Exit($ExitCode)
