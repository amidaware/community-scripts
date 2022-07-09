#There are errors if no user is logged in, hide errors
$ErrorActionPreference = 'silentlycontinue'

$currentuser = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]

# (Get-CimInstance -ClassName Win32_ComputerSystem).Username #ComputerName\LoggedInUsername
#((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1] #LoggedInUsername

If (!$currentuser) {    
    Write-Output "Noone currently logged in"
} else {
    Write-Output "Currently logged in user is: $currentuser"}

$LoggedOnUser =(Get-WmiObject -Class Win32_Process -Filter 'Name="explorer.exe"').GetOwner().User | select-object -first 1
Write-Output "Alt method: Currently logged in user is: $LoggedOnUser"
