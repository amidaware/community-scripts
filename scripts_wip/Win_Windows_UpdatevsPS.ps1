# 2/11/2022 contributed by subz


$ComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem | select name).name
# Add KBs here you do NOT want to install. More than one would be: $HiddenKBArray=('KB5009543', 'KB534234324', 'KB43243243')
$HiddenKBArray=('KB5009543')

Function Get-Updates {
    If ((get-service wuauserv).Status -eq "Running"){
        Write-Output "The Windows Update service is already running"
    
    }Else{
        Write-Output "Starting the Windows Update service"
        Set-Service -Name wuauserv -StartupType "Automatic"
        Start-Service -Name wuauserv
        
    }
    Hide-WindowsUpdate -KBArticleID $HiddenKBArray -MicrosoftUpdate -Hide -Confirm:$false | Out-Null
    # Show-WindowsUpdate -KBArticleID $HiddenKBArray -MicrosoftUpdate -Confirm:$false | Out-Null
    $Updates = Get-WindowsUpdate -MicrosoftUpdate
    If (($Updates | Measure-Object).Count -eq 0){
        Write-Output "No updates to install for $($ComputerName) at this time"
        
    }Else{
        "$(($Updates | Measure-Object).Count) updates ready to download and install for $($ComputerName)"
        $Updates | Format-List -Property Title, KB, @{L='Date';E={($_.LastDeploymentChangeTime).GetDateTimeFormats()[8]}}, @{L='Size';E={If ($_.MaxDownloadSize -lt 1000000000 -And $_.MaxDownloadSize -gt 1000000){"$([math]::Round($_.MaxDownloadSize / 1MB,1)) MB"}ElseIf($_.MaxDownloadSize -lt 1000000){"$([math]::Round($_.MaxDownloadSize / 1KB)) KB"}Else{"$([math]::Round($_.MaxDownloadSize / 1GB,1)) GB"}}}, Description, Status
        Install-WindowsUpdate -AcceptAll -AutoReboot
    }
    If ((get-service wuauserv).Status -eq "Stopped"){
        Write-Output "The Windows Update service is already stopped"
        
    }Else{
        Write-Output "Stopping the Windows Update service"
        Set-Service -Name wuauserv -StartupType "Disable"
        Stop-Service -Name wuauserv
        
    }
}


If (Get-Module -ListAvailable -Name PSWindowsUpdate){
    Get-Updates

}Else{
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name PSWindowsUpdate -Force
    Get-Updates

}