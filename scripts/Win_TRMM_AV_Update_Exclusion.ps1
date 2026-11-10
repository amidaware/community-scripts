#Windows Defender Exclusions for Tactical
Add-MpPreference -ExclusionPath "C:\Program Files\Mesh Agent\*"
Add-MpPreference -ExclusionPath "C:\Program Files\TacticalAgent\*"
Add-MpPreference -ExclusionPath "C:\ProgramData\TacticalRMM\*"
Add-MpPreference -ExclusionPath "C:\Windows\Temp\is-*.tmp\tacticalagent*"
Add-MpPreference -ExclusionProcess "C:\Program Files\TacticalAgent\tacticalrmm.exe"
Add-MpPreference -ExclusionProcess "C:\ProgramData\TacticalRMM\tacticalagent*"
Add-MpPreference -ExclusionProcess "C:\Windows\Temp\is-*.tmp\tacticalagent*"
