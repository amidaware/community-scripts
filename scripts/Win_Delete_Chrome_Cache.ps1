Get-Process chrome -ErrorAction SilentlyContinue | kill -PassThru 

Start-Sleep -Seconds 5 

$Items = @('Archived History', 

            'Cache\*', 

            'Cookies', 

            'History', 

            'Login Data', 

            'Top Sites', 

            'Visited Links', 

            'Web Data') 

$Folder = "$($env:LOCALAPPDATA)\Google\Chrome\User Data\Default" 

$Items | % {  

    if (Test-Path "$Folder\$_") { 

        Remove-Item "$Folder\$_"  -Recurse -Force -Confirm:$false 

    } 

} 
