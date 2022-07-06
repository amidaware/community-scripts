rem TRMM Agent temporarily running in debug mode.

del "C:\Program Files\TacticalAgent\undodebug.bat"
(
echo REM Stop TRMM in debugging mode and start service
taskkill /IM "tacticalrmm.exe" /F
net start "tacticalrmm"
)>"C:\Program Files\TacticalAgent\undodebug.bat"

start "" "C:\Program Files\TacticalAgent\undodebug.bat"