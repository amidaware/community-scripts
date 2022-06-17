#-----------------------------------------------------------[Functions]------------------------------------------------------------

#Make a new folder(s) if they don't exist
if (!(Test-Path -Path $rootdir)) {
    New-Item -ItemType directory -Path $rootdir
}
     
if (!(Test-Path -Path $targetdir)) {
    New-Item -ItemType directory -Path $targetdir
}
    
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
# Encode the Personal Access Token (PAT) to Base64 String
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $token)))
    
# Construct the download URL
$url2 = "https://raw.githubusercontent.com/$gitname/$reponame/main/$filePath/$archivo2"
    
# Download the file
$result = Invoke-RestMethod -Uri $url2 -Method Get -ContentType "application/text" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } | Out-File $dest642
    
    
# CLOUDINARY ASSETS
Invoke-RestMethod -Uri $url64x -OutFile $dest64x
        
# DESCOMPRIMIR
Expand-Archive -LiteralPath $dest64x -DestinationPath C:\Tools\Utils\BGInfo\Settings2 -Force    
    
# EJECUCION COMO USUARIO DEL PC    
Invoke-AsCurrentUser -scriptblock {
    #Copy the settings files to the start of the local server (DC)
    Copy-item $source2 -Destination 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    
    
    C:\ProgramData\chocolatey\lib\bginfo\Tools\Bginfo64.exe C:\Tools\Utils\BGInfo\Settings2\settings.bgi /timer:0 /nolicprompt
}
    
Invoke-AsCurrentUser -scriptblock {
        
    $WScriptShell = New-Object -ComObject WScript.Shell
    $TargetFile = "C:\Tools\Utils\BGInfo\startbginfo.cmd"
    $ShortcutFile = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\bginfo_quiensoy.lnk"
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()
    
        
}
        
    
#-----------------------------------------------------------[Execution]------------------------------------------------------------