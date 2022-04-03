# TODO needs standard comment headers

If (!(test-path "c:\temp")) {
    New-Item -ItemType Directory -Force -Path "c:\temp"
}

If (!(test-path $env:programdata\RMMScripts\)) {
    New-Item -ItemType Directory -Force -Path $env:programdata\TRMMScripts\
}

If (!(test-path 'C:\Program Files\TacticalAgent\bluescreenview.exe')) {
    cd c:\temp
    Invoke-WebRequest https://www.nirsoft.net/utils/bluescreenview.zip -Outfile bluescreenview.zip
    expand-archive bluescreenview.zip
    cd C:\TEMP\bluescreenview\
    move .\bluescreenview.exe 'C:\Program Files\TacticalAgent\'

    start sleep -Seconds 5

    Remove-Item -LiteralPath "c:\temp\bluescreenview.zip" -Force -Recurse
    & 'C:\Program Files\TacticalAgent\bluescreenview.exe' /stext "$env:programdata\TRMMScripts\crashes.txt"
    get-content '$env:programdata\TRMMScripts\crashes.txt'
}

else {
    & 'C:\Program Files\TacticalAgent\bluescreenview.exe' /stext "$env:programdata\TRMMScripts\crashes.txt"
    get-content '$env:programdata\TRMMScripts\crashes.txt'
}

