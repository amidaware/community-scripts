<#
.SYNOPSIS
   Fetches and runs the Autoruns program on the system.

.DESCRIPTION
   This script fetches Autoruns from Sysinternals and runs it to get all automatically running programs on PCs. 
   It also checks these programs against Virus Total, showing how many AV programs detect each autorun as a virus.

.OUTPUTS
   The output is a text file named autoruns.txt located at "$env:programdata\TacticalRMM\scripts\", 
   which contains the Autoruns analysis.

.NOTES
   Version: 1.0 Author: Dave Long <dlong@cagedata.com>
   Version: 1.1 6/6/2023 silversword411 Fixing the script to work with the new toolbox directory structure and standardized comment headers
   Running this script assumes acceptance of the Sysinternals and Virus Total licenses.
#>


If (!(test-path "$env:programdata\TacticalRMM\temp\")) {
    New-Item -ItemType Directory -Force -Path "$env:programdata\TacticalRMM\temp\"
}

If (!(test-path "$env:programdata\TacticalRMM\scripts")) {
    New-Item -ItemType Directory -Force -Path "$env:programdata\TacticalRMM\scripts\"
}

If (!(test-path $env:programdata\TacticalRMM\toolbox\autoruns)) {
    New-Item -ItemType Directory -Force -Path $env:programdata\TacticalRMM\toolbox\autoruns
}

If (!(test-path "$env:programdata\TacticalRMM\toolbox\autoruns\Autorunsc.exe")) {
    Set-Location "$env:programdata\TacticalRMM\temp\"
    Invoke-WebRequest https://download.sysinternals.com/files/Autoruns.zip -Outfile Autoruns.zip
    Expand-Archive -Path Autoruns.zip
    Set-Location "$env:programdata\TacticalRMM\toolbox\Autoruns\"
    Move-Item "$env:programdata\TacticalRMM\temp\autoruns\Autorunsc.exe" "$env:programdata\TacticalRMM\toolbox\Autoruns\"

    Start-sleep -Seconds 5
    REG ADD HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f
    Remove-Item -LiteralPath "$env:programdata\TacticalRMM\temp\Autoruns.zip" -Force -Recurse
    Remove-Item -LiteralPath "$env:programdata\TacticalRMM\temp\Autoruns\" -Force -Recurse
    Start-Process -Wait -FilePath "$env:programdata\TacticalRMM\toolbox\autoruns\autorunsc.exe" -NoNewWindow -PassThru -ArgumentList @("-v", "-vt", "-c", "-o $env:programdata\TacticalRMM\scripts\autoruns.txt")
    Get-Content "$env:programdata\TacticalRMM\scripts\autoruns.txt"
    Remove-Item "$env:programdata\TacticalRMM\scripts\autoruns.txt"
}

else {
    Start-Process -Wait -FilePath "$env:programdata\TacticalRMM\toolbox\autoruns\autorunsc.exe" -NoNewWindow -PassThru -ArgumentList @("-v", "-vt", "-c", "-o $env:programdata\TacticalRMM\scripts\autoruns.txt")
    Get-Content "$env:programdata\TacticalRMM\scripts\autoruns.txt"
    Remove-Item "$env:programdata\TacticalRMM\scripts\autoruns.txt"
}
