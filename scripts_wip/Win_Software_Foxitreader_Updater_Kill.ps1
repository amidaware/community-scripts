# Kill Foxit Updater so it stops prompting users to install 15 day trial of writer by default

Invoke-AsCurrentUser -scriptblock {  
    
    Rename-Item -Path "$env:APPDATA\Foxit Software\Addon\Foxit PDF Reader\FoxitPDFReaderUpdater.exe" -NewName "badFoxitPDFReaderUpdater.exe"
    # Write-Output Write-Output "Runasuser started" | Out-File -append -FilePath c:\temp\raulog.txt
    # Write-Output Get-Content -Path "$env:APPDATA\Foxit Software\Addon\Foxit PDF Reader" | Out-File -append -FilePath c:\temp\raulog.txt
    $Enable = Get-ChildItem "$env:APPDATA\Foxit Software\Addon\Foxit PDF Reader\*.exe"
    Write-Output $Enable | Out-File -append -FilePath c:\temp\raulog.txt
    # Write-Output "Debug output finished" | Out-File -append -FilePath c:\temp\raulog.txt
}

$exitcode = Get-Content -Path "c:\temp\raulog.txt"
Write-Output $exitcode
Remove-Item -path "c:\temp\raulog.txt"
