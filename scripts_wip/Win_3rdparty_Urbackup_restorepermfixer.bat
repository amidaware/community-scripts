rem Use environment variables
rem eg pcname=pcname username=username

rem Display the values of environment variables
echo pcname: %pcname%
echo Username: %username%

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Desktop" /r /d Y
icacls "c:\users\%username%\Desktop" /reset /T

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Documents" /r /d Y
icacls "c:\users\%username%\Documents" /reset /T

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Downloads" /r /d Y
icacls "c:\users\%username%\Downloads" /reset /T

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Favorites" /r /d Y
icacls "c:\users\%username%\Favorites" /reset /T

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Music" /r /d Y
icacls "c:\users\%username%\Music" /reset /T

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Pictures" /r /d Y
icacls "c:\users\%username%\Pictures" /reset /T

takeown /s %pcname% /u %pcname%\%username% /f "c:\users\%username%\Videos" /r /d Y
icacls "c:\users\%username%\Videos" /reset /T