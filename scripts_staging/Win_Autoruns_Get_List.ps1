###
# Author: Dave Long <dlong@cagedata.com>
# Uses Autoruns from Sysinternals to get all automatically running programs on PCs.
# Also tests autoruns against Virtus Total and shows how many AV programs detect
# each autorun as a virus.
#
# Running assumes acceptance of the Sysinternals and Virus Total licenses.
###
If (!(test-path "c:\temp")) {
    New-Item -ItemType Directory -Force -Path "c:\temp"
}

If(!(test-path $env:programdata\RMMScripts\))
{
      New-Item -ItemType Directory -Force -Path $env:programdata\TRMMScripts\
}
If (!(test-path 'C:\Program Files\TacticalAgent\Autorunsc.exe')) {
Set-Location c:\temp
Invoke-WebRequest https://download.sysinternals.com/files/Autoruns.zip -Outfile Autoruns.zip
expand-archive Autoruns.zip
Set-Location C:\TEMP\Autoruns\
Move-Item .\Autorunsc.exe 'C:\Program Files\TacticalAgent\'

Start-sleep -Seconds 5

Remove-Item -LiteralPath "c:\temp\bluescreenview.zip" -Force -Recurse
Start-Process -Wait -FilePath C:\Program Files\TacticalAgent\autorunsc.exe -NoNewWindow -PassThru -ArgumentList @("-v", "-vt", "-c", "-o $env:programdata\TRMMScripts\autoruns.txt")
get-content $env:programdata\TRMMScripts\autoruns.txt
}

else {
Start-Process -Wait -FilePath 'C:\Program Files\TacticalAgent\autorunsc.exe' -NoNewWindow -PassThru -ArgumentList @("-v", "-vt", "-c", "-o $env:programdata\TRMMScripts\autoruns.txt")
get-content $env:programdata\TRMMScripts\autoruns.txt
}
