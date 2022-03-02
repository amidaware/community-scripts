@echo off

echo $ENV:PATH > "%TEMP%\get-info.ps1"
echo $PSVersionTable >> "%TEMP%\get-info.ps1"
echo $Host.version >> "%TEMP%\get-info.ps1"
echo Get-Command powershell.exe >> "%TEMP%\get-info.ps1"

C:\Windows\System32\WindowsPowershell\v1.0\powershell.exe -NonInteractive -ExecutionPolicy Bypass "%TEMP%\get-info.ps1"

del "%TEMP%\get-info.ps1"
