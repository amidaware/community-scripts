<#
.Synopsis
    Outputs Drive Health
.DESCRIPTION
    This was written specifically for use as a "Script Check" in mind, where it the output is deliberaly light unless a warning or error condition is found that needs more investigation.

    Uses the Windows Storage Reliabilty Counters first (the information behind Settings - Storage - Disks & Volumes - %DiskID% - Drive health) to report on drive health.
    
    Will exit if running on a virtual machine.
    
.NOTES
    Learing taken from "Win_Disk_SMART2.ps1" by nullzilla, and modified by: redanthrax
#>

# Requires -Version 5.0
# Requires -RunAsAdministrator
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $false)]
    [int]#Warn if the temperature (in degrees C) is over this limit
    $TemperatureWarningLimit = 60,

    [Parameter(Mandatory = $false)]
    [int]#Warn if the "wear" of the drive (as a percentage) is above this
    $maximumWearAllowance = 20
)

BEGIN {
        # If this is a virtual machine, we don't need to continue
        $Computer = Get-CimInstance -ClassName 'Win32_ComputerSystem'
        if ($Computer.Model -like 'Virtual*') {
            exit
        }
    }

PROCESS {
    Try{
        #Using Windows Storage Reliabilty Counters first (the information behind Settings - Storage - Disks & Volumes - %DiskID% - Drive health)
        $physicalDisks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($disk in $physicalDisks) {
            $reliabilityCounter = $null
            try {
                $reliabilityCounter = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
            }
            catch {
                Write-Error "No Storage Reliability Counter for '$($disk.FriendlyName)'. This usually means the driver/controller isn't exposing it."
            }
            $driveLetters = (get-disk -FriendlyName $Disk.FriendlyName | Get-Partition | Where-Object -FilterScript {$_.DriveLetter} | Select-Object -Expand DriveLetter) -join ", "

            <#
                DriveLetters            = $driveLetters
                HealthStatus			= $disk.HealthStatus
                FriendlyName			= $disk.FriendlyName
                SerialNumber			= $disk.SerialNumber
                BusType					= $disk.BusType
                OperationalStatus		= ($disk.OperationalStatus -join ", ")
                Temperature 			= $reliabilityCounter.Temperature
                Wear					= $reliabilityCounter.Wear
                ReadErrorsTotal			= $reliabilityCounter.ReadErrorsTotal
                WriteErrorsTotal		= $reliabilityCounter.WriteErrorsTotal
                ReallocatedSectors		= $reliabilityCounter.ReallocatedSectors
                PowerOnHours			= $reliabilityCounter.PowerOnHours
            #>    
            If(
                $disk.HealthStatus.ToLower() -ne "healthy" -or
                ($disk.OperationalStatus | Where-Object -FilterScript { $_.ToLower() -ne "ok" }) -or
                $reliabilityCounter.Wear -gt $maximumWearAllowance -or
                $reliabilityCounter.Temperature -gt $TemperatureWarningLimit
            ){
                "Disk issue: $DriveLetters $($disk.HealthStatus) Status:$(($disk.OperationalStatus -join ", ")) $($reliabilityCounter.Temperature)*C $($reliabilityCounter.Wear)% wear"
                Write-Error -Message "Disk issues need investigating"
            } else {
                "$DriveLetters $($disk.HealthStatus) Status:$(($disk.OperationalStatus -join ", ")) $($reliabilityCounter.Temperature)*C $($reliabilityCounter.Wear)% wear"
            }
        }
    } catch {
        Write-Error -Message "Get-PhysicalDisk failed. This can happen on older OS builds or restricted environments."
    }
}

END{
    if ($error) { Exit 1 }
    Exit 0
}