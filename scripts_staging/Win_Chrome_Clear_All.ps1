#This Script will clear all chrome history, cookies and cache for the currently logged in user.
#
#

Write-Output --------------------------------------
Write-Output **** Clearing Chrome cache
$liu = ((Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object UserName).Username).Split("\")[1]
taskkill /F /IM "chrome.exe"

$ChromeDataDir = "C:\Users\$liu\AppData\Local\Google\Chrome\User Data\Default"
$ChromeCache = %ChromeDataDir%\Cache  
Get-ChildItem $ChromeCache -Recurse | Remove-Item -Force  
Get-ChildItem $ChromeDataDir\*Cookies -Recurse | Remove-Item -Force   
Get-ChildItem $ChromeDataDir\*History -Recurse | Remove-Item -Force       

$ChromeDataDir = "C:\Users\$liu\Local Settings\Application Data\Google\Chrome\User Data\Default"
$ChromeCache = %ChromeDataDir%\Cache
Get-ChildItem $ChromeCache -Recurse | Remove-Item -Force  
Get-ChildItem $ChromeDataDir\*Cookies -Recurse | Remove-Item -Force   
Get-ChildItem $ChromeDataDir\*History -Recurse | Remove-Item -Force   
Write-Output **** Clearing Chrome cache DONE
