# From xrsxj

if (!(Test-Path -Path "C:\BGInfo")) {
    New-Item -Path "C:\" -Name "BGInfo" -ItemType "directory" | Out-Null
}
$files = "bg.bgi", "Bginfo.exe", "Bginfo64.exe"
Write-Output "Downloading BGInfo Files"
foreach ($file in $files) {
    $url = "https://domain.com/1p92unbr987nbcv08zw67sbv086b1/$file"
    $path = "C:\BGInfo\$file"
    try {
        (New-Object Net.WebClient).DownloadFile($url, $path) 
    }
    catch {
        throw "Unable to download $file"
    }
}
Write-Output "Creating BGInfo Shortcut in All Users startup"
if ([Environment]::Is64BitOperatingSystem) {
    $objShell = New-Object -ComObject ("WScript.Shell")
    $objShortCut = $objShell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\BGInfo.lnk")
    $objShortCut.TargetPath = "C:\BGInfo\BGInfo64.exe"
    $objShortCut.Arguments = "c:\BGInfo\bg.bgi /silent /timer0 /nolicprompt"
    $objShortCut.WorkingDirectory = "C:\BGInfo\"
    $objShortCut.Save()
}
else {
    $objShell = New-Object -ComObject ("WScript.Shell")
    $objShortCut = $objShell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\BGInfo.lnk")
    $objShortCut.TargetPath = "C:\BGInfo\BGInfo.exe"
    $objShortCut.Arguments = "c:\BGInfo\bg.bgi /silent /timer0 /nolicprompt"
    $objShortCut.WorkingDirectory = "C:\BGInfo\"
    $objShortCut.Save()
}