#Windows Defender Exclusions for Tactical
Add-MpPreference -ExclusionPath "C:\Program Files\Mesh Agent\*"
Add-MpPreference -ExclusionPath "C:\Program Files\TacticalAgent\*"
Add-MpPreference -ExclusionPath "C:\ProgramData\TacticalRMM\*"
# For agent updates. Inno setup temp directory
Add-MpPreference -ExclusionPath "%TEMPDIR%\is-*.tmp\tacticalagent*"
