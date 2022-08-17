# List all exclusions
# Use Remove-MpPreference -ExclusionPath C:\Windows\Temp\trmm\*
# and Add-MpPreference -ExclusionPath 'C:\ProgramData\TacticalRMM\*'

Get-MpPreference | Select-Object -Property ExclusionPath