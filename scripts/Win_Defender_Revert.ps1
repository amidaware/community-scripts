<#
      .SYNOPSIS
      Resets Windows Defender back to defaults
      .DESCRIPTION
      Windows Defender reset to default configuration
      .NOTES
      6/2022 v1 Initial release
#>


# make sure the base options are on
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableIOAVProtection $false

# set exclusions to default
$pathExclusions = Get-MpPreference | select ExclusionPath 
foreach ($exclusion in $pathExclusions) {
    if ($exclusion.ExclusionPath -ne $null) {
        Remove-MpPreference -ExclusionPath $exclusion.ExclusionPath
    }
}
$extensionExclusion = Get-MpPreference | select ExclusionExtension 
foreach ($exclusion in $extensionExclusion) {
    if ($exclusion.ExclusionExtension -ne $null) {
        Remove-MpPreference -ExclusionExtension $exclusion.ExclusionExtension
    }
}
$processExclusions = Get-MpPreference | select ExclusionProcess
foreach ($exclusion in $processExclusions) {
    if ($exclusion.ExclusionProcess -ne $null) {
        Remove-MpPreference -ExclusionProcess $exclusion.ExclusionProcess
    }
}

# set scans to default
Set-MpPreference -ScanScheduleTime "02:00:00"
Set-MpPreference -ScanScheduleQuickScanTime "02:00:00"
Set-MpPreference -DisableCatchupFullScan $true
Set-MpPreference -DisableCatchupQuickScan $true
Set-MpPreference -DisableArchiveScanning $false

# packed executable scanning set to enabled
Set-MpPreference -DisableRemovableDriveScanning $false
Set-MpPreference -DisableScanningNetworkFiles $true

# set signatures to default
Set-MpPreference -SignatureUpdateInterval 6
Set-MpPreference -SignatureUpdateCatchupInterval 1
Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $false
Set-MpPreference -SignatureFallbackOrder "MicrosoftUpdateServer|MMPC"

# set advanced options to default
Set-MpPreference -QuarantinePurgeItemsAfterDelay 90