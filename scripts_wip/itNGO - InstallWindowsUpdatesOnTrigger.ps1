$u = Start-WUScan -SearchCriteria "IsInstalled=0"
Install-WUUpdates -Updates $u -DownloadOnly $true
Install-WUUpdates -Updates $u
Get-WUIsPendingReboot