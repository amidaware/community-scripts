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
    $TemperatureWarningLimit = 55,

    [Parameter(Mandatory = $false)]
    [int]#Warn if the "wear" of the drive (as a percentage) is above this
    $maximumWearAllowance = 20,
    
    [Parameter(Mandatory = $false)]
    [switch]#Outputs a full report, instead of warnings only
    $fullReport
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
        $storageResults = @()
        foreach ($disk in $physicalDisks) {
            $reliabilityCounter = $null
            try {
                $reliabilityCounter = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
            }
            catch {
                Write-Error "No Storage Reliability Counter for '$($disk.FriendlyName)'. This usually means the driver/controller isn't exposing it."
            }

            $storageResults += [pscustomobject]@{
                FriendlyName			= $disk.FriendlyName
                SerialNumber			= $disk.SerialNumber
                BusType					= $disk.BusType
                HealthStatus			= $disk.HealthStatus
                OperationalStatus		= ($disk.OperationalStatus -join ", ")
                Temperature 			= $reliabilityCounter.Temperature
                Wear					= $reliabilityCounter.Wear
                ReadErrorsTotal			= $reliabilityCounter.ReadErrorsTotal
                WriteErrorsTotal		= $reliabilityCounter.WriteErrorsTotal
                ReallocatedSectors		= $reliabilityCounter.ReallocatedSectors
                PowerOnHours			= $reliabilityCounter.PowerOnHours
            }

            If(
                $disk.HealthStatus.ToLower() -ne "healthy" -or
                ($disk.OperationalStatus | Where-Object -FilterScript { $_.ToLower() -ne "ok" }) -or
                $reliabilityCounter.Wear -ge $maximumWearAllowance -or
                $reliabilityCounter.Temperature -ge $TemperatureWarningLimit
            ){
                Write-Error -Message "$($disk.FriendlyName) has conditions that require investigation. $storageResults"
            }
        }

        If($fullReport) { $storageResults }

    } catch {
        Write-Error -Message "Get-PhysicalDisk failed. This can happen on older OS builds or restricted environments."
    }
}

END{
    if ($error) {
        Write-Output $error
        exit 1
    }
    Write-Output "All drives report as healthy"
    Exit 0
}