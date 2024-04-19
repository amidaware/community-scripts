# This will check Duplicati Backup is running properly over the last 24 hours
################
# Please make sure you have created the 2 files Duplicati_Before.bat and Duplicati_After.bat and saved them in a folder
################ 
# Change the Duplicati backup advanced settings to run the before script and after script you will need their full path
################
# Duplicati_Before.bat should contain the below without the proceeding #:
#
# REM Create Running Status
# EVENTCREATE /T INFORMATION /L APPLICATION /SO Duplicati2 /ID 205 /D "%DUPLICATI__BACKUP_NAME% - Starting Duplicati Backup Job"
################
# Duplicati_After.bat should contain the below without the proceeding #:
#
# REM Create Result Status from Parsed Results
# SET DSTATUS=%DUPLICATI__PARSED_RESULT%
# If %DSTATUS%==Fatal GOTO DSError
# If %DSTATUS%==Error GOTO DSError
# If %DSTATUS%==Unknown GOTO DSWarning
# If %DSTATUS%==Warning GOTO DSWarning
# If %DSTATUS%==Success GOTO DSSuccess
# GOTO END
# :DSError
# EVENTCREATE /T ERROR /L APPLICATION /SO Duplicati2 /ID 202 /D "%DUPLICATI__BACKUP_NAME% - Error running Duplicati Backup Job"
# GOTO END
# :DSWarning
# EVENTCREATE /T WARNING /L APPLICATION /SO Duplicati2 /ID 201 /D "%DUPLICATI__BACKUP_NAME% - Warning running Duplicati Backup Job"
# GOTO END
# :DSSuccess
# EVENTCREATE /T SUCCESS /L APPLICATION /SO Duplicati2 /ID 200 /D "%DUPLICATI__BACKUP_NAME% - Success in running Duplicati Backup Job"
# GOTO END
# :END
# SET DSTATUS=

$ErrorActionPreference = 'silentlycontinue'

# Name of the service to check
$serviceName = 'Duplicati'  # change this to the actual service name you want to check

# Check if the service exists
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Output "The service $serviceName does not exist on this system."
    $host.SetShouldExit(0)  # Exit code 0 for "service not found"
    return
}

# Define the time spans for the last 24 hours and the last 5 days
$Last24Hours = (Get-Date) - (New-TimeSpan -Days 1)
$Last5Days = (Get-Date) - (New-TimeSpan -Days 5)

# Fetch events from the last 5 days and last 24 hours
$eventsLast5Days = Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = 200; StartTime = $Last5Days} -ErrorAction SilentlyContinue | Sort-Object TimeCreated
$eventsLast24Hours = Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = 200; StartTime = $Last24Hours} -ErrorAction SilentlyContinue | Sort-Object TimeCreated

# Check for any successful backup in the last 5 days
if ($eventsLast5Days) {
    $lastSuccessfulBackup = $eventsLast5Days | Select-Object -Last 1
    $lastBackupTime = $lastSuccessfulBackup.TimeCreated
    Write-Output "Last successful Duplicati Backup in the last 5 days was at $lastBackupTime"
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '205', '200', '201' }
    
    # Check if there was a successful backup in the last 24 hours
    if ($eventsLast24Hours) {
        Write-Output "There has been a successful backup in the last 24 hours."
        Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '205', '201', '202'; StartTime = $eventsLast24Hours }
        $host.SetShouldExit(0)  # Exit code 0 for success
    } else {
        Write-Output "No successful backup in the last 24 hours."
        Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '205', '200', '201' }
        $host.SetShouldExit(1)  # Exit code 1 for error
    }
} else {
    Write-Output "No successful Duplicati Backup found in the last 5 days."
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '205', '200', '201' }
    $host.SetShouldExit(1)  # Exit code 1 for error
}

