param (
    [switch]$debug,
    [switch]$listExclusions,
    [switch]$warnIfExclusions,
    [switch]$updateSignatures,
    [switch]$startQuickScan,
    [switch]$startFullScan,
    [switch]$startWDOScan,
    [switch]$removeThreat,
    [switch]$customScan,
    [string]$customScanPath
)

# For setting debug output level. -debug switch will set $debug to true
if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

$exitCode = 0  # Initialize the exit code variable

if ($debug) {
    Write-Debug "Debugging: All Defender Options"
    Get-MpPreference | Format-List -Property *
}

if ($listExclusions) {
    Write-Debug "Defender Exclusions"
    Get-MpPreference | Select Exc* | Format-List -Property *
}

if ($warnIfExclusions) {
    Write-Debug "Defender Exclusions"
    $exclusions = Get-MpPreference | Select Exc* | Format-List -Property *

    if ($exclusions -ne $null) {
        Write-Output "WARNING: Defender exclusions are configured."
        $exitCode = 1
    }
    else {
        Write-Output "No Defender exclusions found."
    }
}

function defenderStatus() {
    # List Defender Status
    $defenderStatus = Get-MpPreference

    if ($defenderStatus -eq $false) {
        Write-Output "WARNING: Windows Defender is not enabled."
        $exitCode = 1
    }
    else {
        Write-Output "Windows Defender is enabled."
    }
}
defenderStatus

if ($updateSignatures) {
    Write-Output "Updating Signatures"
    Update-MpSignature
}

if ($startQuickScan) {
    Write-Output "Starting Quick Scan"
    Start-MpScan -ScanType QuickScan
}

if ($startFullScan) {
    Write-Output "Starting Full Scan"
    Start-MpScan -ScanType FullScan
}

if ($startWDOScan) {
    Write-Output "Starting Windows Defender Offline Scan"
    Start-MpWDOScan
}

if ($customScan) {
    if ($customScanPath -ne $null) {
        Write-Output "Path required when using customScan switch"
        Exit 1
    }
    else {
        Start-MpScan -ScanType CustomScan -ScanPath $customScanPath
    }
}

if ($removeThreat) {
    Write-Output "Removing Threats"
    Remove-MpThreat
}

# Exit with the final exit code
exit $exitCode