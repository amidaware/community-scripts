<#
.SYNOPSIS
   Monitor SPX Backups

.DESCRIPTION
   Checks to see of scheduled SPX backups are completing or failing. Returns Result.

.PARAMETER FailThreshold
   Number of failed backups to tolerate before raising an alert.
   Defaults to 3.

.PARAMETER PSSQLLiteIsInstalled
   Lets the script know if it can skip the (expensive) check to see if PSSQLLite Is Installed
   Defaults to $False

.OUTPUTS
   Exit Code: 0 = Pass, 1 = Informational, 2 = Warning, 3 = Error

.EXAMPLE
   Win_ShadowProtectSPX_BackupStatus.ps1
   #No Parameters, defaults apply

.EXAMPLE
   Win_ShadowProtectSPX_BackupStatus.ps1 (4, $True)
   #Specify Parameters for Failure Threshold and PSSQLLiteIsInstalled

.NOTES
   v1.1 11/29/2023 ConvexSERV
   Utilizes PSSQLLite Module to query the SPX database.
#>

param (
    [Int] $FailThreshold,
    [Boolean] $PSSQLLiteIsInstalled
)

#Set Parameter Defaults
if (!$FailThreshold) {$FailThreshold = 3}
if (!$PSSQLLiteIsInstalled) {$PSSQLLiteIsInstalled = $False}

#Initialize Variables
$NowTime = [DateTime]::Now
$AlertLevel = 0 #0 = Pass, 1 = Informational, 2 = Warning, 3 = Error
$AlertText = ''
$SPXDB = 'C:\ProgramData\StorageCraft\spx\spx.db3'

If (Test-Path $SPXDB) {

    #Allow passing in $PSSQLLiteIsInstalled as a parameter to skip the check to see if it's installed.
    if (-not($PSSQLLiteIsInstalled)){
        #This script requires the PSSQLite Module. Check is it's installed.
        $InstalledModules = Get-Module -ListAvailable
        foreach ($Module in $InstalledModules){
            if ($Module.Name -eq 'PSSQLite'){
                $PSSQLLiteIsInstalled = $True
                break
            }
        }

        #If PSSQLite is not already installed, install it now.
        if (-not($PSSQLLiteIsInstalled)) {
            Install-PackageProvider NuGet -Force
            Install-Module PSSQLite -Confirm:$False -Force

            #ToDo - Set a KeyPair to let the RMM know that PSSQLLite Is Installed and to skip the check next time.
            #Do That Here
        }
    }

    #Catch the Exception if we can't import PSSQLite
    Try {Import-Module PSSQLite}
    Catch {

        #PSSQLite Module failed to load, try running the check without parameters
        $AlertText = "PSSQLite Module failed to load, try running the check without parameters"
        $AlertLevel = 3

        #Report back to the RMM
        Write-Output $AlertText
        $Host.SetShouldExit($AlertLevel)
        Exit

    }

    #Get the backup job entries from the SPX Database
    $Qry = 'SELECT id, name, created, schedule_id, settings, paused, description, destination_id FROM job'
    $Jobs = Invoke-SqliteQuery -DataSource $SPXDB -Query $Qry

    ForEach ($Job in $Jobs){

        $JobCreated = [DateTime]::$Job.created

        #Get the backup job results from the SPX Database, in descending order (newest at the top)
        $Job_ID = $Job.id
        $Qry = "SELECT id, updated, ts, dt, result, summary_type, mode, snapshot_method, size, info, is_completed FROM job_event WHERE job_id = $Job_ID order by id desc"
        $JobEvents = Invoke-SqliteQuery -DataSource $SPXDB -Query $Qry

        #Check to see if the last backup is more than 3 days old
        $LastBackup = $JobEvents[0]
        $LastBackupTS = $LastBackup.ts
        If ($LastBackupTS -lt $NowTime.AddDays(-3)){

            #We haven't had a backup in over 3 days. Fail the Check.
            $AlertText = "Backups are not running. Last Backup attempt was $LastBackupTSs"
            $AlertLevel = 3

        } Else #Investigate Further...
        {

            #Walk the Events, looking for failures
            $FailCount = 0
            ForEach ($JobEvent in $JobEvents){

                If ($JobEvent.is_completed -eq 1){

                    If ($FailCount -eq 0){

                        #Last Backup was successful. Pass the Check.
                        $LastBackupTS = $JobEvent.ts
                        $AlertText = "Last Backup completed at $LastBackupTS"
                        $AlertLevel = 0
                        break

                    } Else
                    {
                        #We have failures, but have not met the threshold. Pass with a Warning.
                        $LastBackupTS = $JobEvent.ts
                        $AlertText = "Last $FailCount Backup(s) Failed. Last successful Backup completed at $LastBackupTS (Threshold not met)"
                        $AlertLevel = 2
                    }


                } Else
                {
                    #Increment the Fail Count.
                    $FailCount++
                }

                If ($FailCount -ge $FailThreshold){

                        #We have Backup failures amd have met the failure threshold
                        $AlertText = "Last $FailCount Backup(s) Failed. (Failure Threshold met)"
                        $AlertLevel = 3
                        Break
                }
            }
        }
    }

} Else{

    #The SPX Database Doesn't Exist. Is SPX Even Installed?
    $AlertText = "StorageCraft SPX Does not appear to be properly installed. (DB Not Found.)"
    $AlertLevel = 3

}

#Report back to the RMM
Write-Output $AlertText
$Host.SetShouldExit($AlertLevel)
Exit
