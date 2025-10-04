# This script returns the list of all users and checks
# if they are enabled or disabled

Get-LocalUser | Select Name,Enabled | foreach { Write-Output $_ }
