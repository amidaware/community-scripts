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
$serviceName = 'Duplicati'  # Update this to your specific service name if different

# Check if the service exists
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Output "The service $serviceName does not exist on this system."
    $host.SetShouldExit(0)  # Using exit code 0 for "service not found"
    return
}

# Define the time spans for the last 24 hours and the last 5 days
$Last24Hours = (Get-Date) - (New-TimeSpan -Days 1)
$Last10Days = (Get-Date) - (New-TimeSpan -Days 10)

# Fetch error events from the last 24 hours
$errorEvents = Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = 202; StartTime = $Last24Hours} -ErrorAction SilentlyContinue | Sort-Object TimeCreated

# Check for any errors in the last 24 hours first
if ($errorEvents) {
    Write-Output "Error(s) found in Duplicati Backup within the last 24 hours."
    foreach ($event in $errorEvents) {
        Write-Output "Error at $($event.TimeCreated): $($event.Message)"
        Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '202', '200', '201' }
    }
    $host.SetShouldExit(1)  # Exit code 1 for error
    return
}

# If no errors, check for successful backup events in the last 5 days
$successEvents = Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '200', '201'; StartTime = $Last10Days} -ErrorAction SilentlyContinue | Sort-Object TimeCreated

if ($successEvents) {
    $lastSuccessfulEvent = $successEvents | Select-Object -Last 1
    Write-Output "Last successful Duplicati Backup was at $($lastSuccessfulEvent.TimeCreated)"
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '202', '200', '201' }
    $host.SetShouldExit(0)  # Exit code 0 for success
} else {
    Write-Output "No successful Duplicati Backup found in the last 10 days."
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; ID = '202', '200', '201' }
    $host.SetShouldExit(1)  # Exit code 1 for error
}
