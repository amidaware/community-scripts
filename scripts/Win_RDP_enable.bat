REM WARNING : This script is a bit agressive with the power settings.

powercfg.exe /hibernate off
powercfg /CHANGE hibernate-timeout-ac 0
powercfg /CHANGE hibernate-timeout-dc 0
Powercfg /CHANGE standby-timeout-ac 0
powercfg /CHANGE standby-timeout-dc 0
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
net start TermService

REM net localgroup "Remote Desktop Users" "%UserName%" /add
