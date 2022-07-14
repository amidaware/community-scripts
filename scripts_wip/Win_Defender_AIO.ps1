


# List Defender Status

Get-MpComputerStatus

# TODO Filtered list of Defender status, warn on problems
# TODO Return Defender Exclusions

# List Preferences

Get-MpPreference

# List Exclusions
# TODO: return errors when there are exclusions

Get-MpPreference | Select Exc* | Format-List -

# Scan Downloads

Start-MpScan -ScanType CustomScan -ScanPath "C:\Users\user\Downloads"

# Update signatures

Update-MpSignature

# Quick Scan

Start-MpScan -ScanType QuickScan

# Full Scan

Start-MpScan -ScanType FullScan

# Offline Virus scan - Computer will reboot

Start-MpWDOScan

# Auto-clean all detected Threats

Remove-MpThreat

# TODO 
# TODO 
# TODO 
# TODO 
