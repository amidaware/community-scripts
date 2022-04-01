rem This will stop the TRMM services and manually launch TRMM in debug mode. 
rem You can then use Win_TRMM_GetLogs.ps1 to collect as needed
rem Restart the computer to stop debug and return agent to regular mode

(
echo REM Stop TRMM services and start with debugging
echo net stop "tacticalrmm"
echo start "" "C:\Program Files\TacticalAgent\tacticalrmm.exe" -m svc -log debug
)>"C:\Program Files\TacticalAgent\runasdebug.bat"

start "" "C:\Program Files\TacticalAgent\runasdebug.bat"