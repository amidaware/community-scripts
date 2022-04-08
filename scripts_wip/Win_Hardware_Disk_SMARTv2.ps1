# Requires -Version 4.0
# Requires -RunAsAdministrator

<#
.Synopsis
   Outputs SMART data
.DESCRIPTION
   Checks the system for a comprehensive list of SMART data.
   Will exit on finding a virtual machine.
   Use the -Warning flag to only get warnings instead of all data.
   Use the -Pretty flag to make the output pretty.
.EXAMPLE
    Win_Hardware_Disk_SMART
.EXAMPLE
    Win_Hardware_Disk_SMART -Warning
.EXAMPLE
    Win_Hardware_Disk_SMART -Warning -Pretty
.NOTES
   Version: 1.0
   Author: nullzilla
   Modified by: redanthrax
#>

Param(
    [Parameter(Mandatory = $false)]
    [switch]$Warning,

    [Parameter(Mandatory = $false)]
    [switch]$Pretty
)

function Win_Hardware_Disk_SMART {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$Warning,

        [Parameter(Mandatory = $false)]
        [switch]$Pretty
    )

    Begin {
        # If this is a virtual machine, we don't need to continue
        $Computer = Get-CimInstance -ClassName 'Win32_ComputerSystem'
        if ($Computer.Model -like 'Virtual*') {
            exit
        }
    }

    Process {
        Try {
            $data = @{}
            $disks = (Get-CimInstance -Namespace 'Root\WMI' -ClassName 'MSStorageDriver_FailurePredictStatus' | Select-Object 'InstanceName')
            foreach ($disk in $disks.InstanceName) {
                $SmartData = (Get-CimInstance -Namespace 'Root\WMI' -ClassName 'MSStorageDriver_ATAPISMartData' | Where-Object 'InstanceName' -eq $disk)
                [Byte[]]$RawSmartData = $SmartData | Select-Object -ExpandProperty 'VendorSpecific'
                # Starting at the third number (first two are irrelevant)
                # get the relevant data by iterating over every 12th number
                # and saving the values from an offset of the SMART attribute ID
                [PSCustomObject[]]$Output = for ($i = 2; $i -lt $RawSmartData.Count; $i++) {
                    if (0 -eq ($i - 2) % 12 -and $RawSmartData[$i] -ne 0) {
                        # Construct the raw attribute value by combining the two bytes that make it up
                        [Decimal]$RawValue = ($RawSmartData[$i + 6] * [Math]::Pow(2, 8) + $RawSmartData[$i + 5])
            
                        $InnerOutput = [PSCustomObject]@{
                            ID       = $RawSmartData[$i]
                            #Flags    = $RawSmartData[$i + 1]
                            #Value    = $RawSmartData[$i + 3]
                            Worst    = $RawSmartData[$i + 4]
                            RawValue = $RawValue
                        }
            
                        $InnerOutput
                    }
                }

                $diskData = [PSCustomObject]@{
                    "Realocated Sector Count"                        = ($Output | Where-Object ID -eq 5 | Select-Object -ExpandProperty RawValue)
                    "Spin Retry Count"                               = ($Output | Where-Object ID -eq 10 | Select-Object -ExpandProperty RawValue)
                    "Recalibration Retries"                          = ($Output | Where-Object ID -eq 11 | Select-Object -ExpandProperty RawValue)
                    "Used Reserved Block Count Total"                = ($Output | Where-Object ID -eq 179 | Select-Object -ExpandProperty RawValue)
                    "Erase Failure Count"                            = ($Output | Where-Object ID -eq 182 | Select-Object -ExpandProperty RawValue)
                    "SATA Downshift Error Countor Runtime Bad Block" = ($Output | Where-Object ID -eq 183 | Select-Object -ExpandProperty RawValue)
                    "End-to-End error / IOEDC"                       = ($Output | Where-Object ID -eq 184 | Select-Object -ExpandProperty RawValue)
                    "Reported Uncorrectable Errors"                  = ($Output | Where-Object ID -eq 187 | Select-Object -ExpandProperty RawValue)
                    "Command Timeout"                                = ($Output | Where-Object ID -eq 188 | Select-Object -ExpandProperty RawValue)
                    "High Fly Writes"                                = ($Output | Where-Object ID -eq 189 | Select-Object -ExpandProperty RawValue)
                    "Temperature Celcius"                            = ($Output | Where-Object ID -eq 194 | Select-Object -ExpandProperty RawValue)
                    "Reallocation Event Count"                       = ($Output | Where-Object ID -eq 196 | Select-Object -ExpandProperty RawValue)
                    "Current Pending Sector Count"                   = ($Output | Where-Object ID -eq 197 | Select-Object -ExpandProperty RawValue)
                    "Uncorrectable Sector Count"                     = ($Output | Where-Object ID -eq 198 | Select-Object -ExpandProperty RawValue)
                    "UltraDMA CRC Error Count"                       = ($Output | Where-Object ID -eq 199 | Select-Object -ExpandProperty RawValue)
                    "Soft Read Error Rate"                           = ($Output | Where-Object ID -eq 201 | Select-Object -ExpandProperty RawValue)
                    "SSD Life Left"                                  = ($Output | Where-Object ID -eq 231 | Select-Object -ExpandProperty RawValue)
                    "SSD Media Wear Out Indicator"                   = ($Output | Where-Object ID -eq 233 | Select-Object -ExpandProperty RawValue)
                    "FailurePredictStatus"                           = (
                        Get-CimInstance -Namespace 'Root\WMI' -ClassName 'MSStorageDriver_FailurePredictStatus' |
                        Select-Object PredictFailure, Reason
                    )
                    "DiskDriveOkay"                                  = (
                        Get-CimInstance -ClassName 'Win32_DiskDrive' |
                        Select-Object -ExpandProperty Status 
                    )
                    "PhysicalDiskOkayAndHealthy"                     = (
                        Get-PhysicalDisk |
                        Select-Object OperationalStatus, HealthStatus
                    )
                }

                $data.Add($disk, $diskData)
            }

            #Only output warnings
            if ($Warning) {
                $warnings = @{}
                $data.GetEnumerator() | Foreach-Object {
                    $diskWarnings = @{}
                    $_.Value.psobject.Members | ForEach-Object {
                        $item = $_
                        switch ($_.Name) {
                            "Realocated Sector Count" { if ($null -ne $item.Value -and $item.Value -gt 1) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Recalibration Retries" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Used Reserved Block Count Total" { if ($null -ne $item.Value -and $item.Value -gt 1) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Erase Failure Count" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "SATA Downshift Error Countor Runtime Bad Block" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "End-to-End error / IOEDC" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Reported Uncorrectable Errors" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Command Timeout" { if ($null -ne $item.Value -and $item.Value -gt 2) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "High Fly Writes" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Temperature Celcius" { if ($null -ne $item.Value -and $item.Value -gt 50) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Reallocation Event Count" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Current Pending Sector Count" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Uncorrectable Sector Count" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "UltraDMA CRC Error Count" { if ($null -ne $item.Value -and $item.Value -ne 0) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "Soft Read Error Rate" { if ($null -ne $item.Value -and $item.Value -lt 95) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "SSD Life Left" { if ($null -ne $item.Value -and $item.Value -lt 50) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "SSD Media Wear Out Indicator" { if ($null -ne $item.Value -and $item.Value -lt 50) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "FailurePredictStatus" { if ($item.Value | Where-Object PredictFailure -ne $False) { $diskWarnings.Add($item.Name, $item.Value) } }
                            "DiskDriveOkay" { if ($null -ne $item.Value -and $item.Value -ne 'OK') { $diskWarnings.Add($item.Name, $item.Value) } }
                            "PhysicalDiskOkayAndHealthy" { if ($item.Value | Where-Object { ($_.OperationalStatus -ne 'OK') -or ($_.HealthStatus -ne 'Healthy') }) { $diskWarnings.Add($item.Name, $item.Value) } }
                        }
                    }

                    if ($diskWarnings.Count -gt 0) {
                        $warnings.Add($_.Key, $diskWarnings)
                    }
                }

                if ($warnings.Count -gt 0) {
                    if ($Pretty) {
                        foreach ($key in $warnings.Keys) {
                            Write-Output "Disk: $key"
                            Write-Output $warnings[$key]
                        }
                    }
                    else {
                        $warnings
                    }
                    
                    Exit 1
                }
            }
            else {
                if ($Pretty) {
                    foreach ($key in $data.Keys) {
                        Write-Output "Disk: $key"
                        Write-Output $data[$key]
                    }
                }
                else {
                    $data
                }
            }
        }

        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        if ($Error) {
            if ($Error -match "Not supported") {
                Write-Output "You may need to switch from ACHI to RAID/RST mode, see the link for how to do this non-destructively: https://www.top-password.com/blog/switch-from-raid-to-ahci-without-reinstalling-windows/"
            }
            
            Write-Output $Error
            exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_Hardware_Disk_SMART' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    Warning = $Warning
    Pretty  = $Pretty
}

Win_Hardware_Disk_SMART @scriptArgs