<#
.SYNOPSIS
    Manages bitlocker encryption.
.DESCRIPTION
    A script to manage bitlocker on a workstation. Get information on volumes, keys,
    tpm, and tpm health. Encrypt, Decrypt, Suspend, Resume, and backup. HealBitlocker is
    for the circumstance when you receive an odd error when trying to get the bitlocker
    volume "Get-CimInstance : Invalid property"
.EXAMPLE 
    .\Win_ManageBitlocker.ps1 -Info Keys
    .\Win_ManageBitlocker.ps1 -Info Tpm,TpmHealth
    .\Win_ManageBitlocker.ps1 -Operation Encrypt,Backup
    .\Win_ManageBitlocker.ps1 -Operation HealBitlocker
.INSTRUCTIONS
.NOTES
    Version: 1.0
    Author: red
    Creation Date: 2024-03-13
#>

Param(
    [Parameter(HelpMessage = "Output volumes in Json format")]
    [switch]$Json,

    [Parameter(HelpMessage = "Info: Volumes, Keys, Tpm, TpmHealth, Status")]
    [AllowNull()]
    [AllowEmptyCollection()]
    [string[]]$Info,

    [Parameter(HelpMessage = "Operation: Encrypt, Decrypt, Suspend, Resume, Backup, HealBitlocker")]
    [AllowNull()]
    [AllowEmptyCollection()]
    [string[]]$Operation
)

function Win_ManageBitlocker {
    [CmdletBinding()]
    Param(
        [Parameter(HelpMessage = "Output volumes in Json format")]
        [switch]$Json,

        [Parameter(HelpMessage = "Info: Volumes, Keys, Tpm, TpmHealth, Status")]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Info,

        [Parameter(HelpMessage = "Operation: Encrypt, Decrypt, Suspend, Resume, Backup, HealBitlocker")]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Operation
    )

    Begin {}

    Process {
        Try {
            #Info Section - Information Gathering
            foreach ($item in $Info) {
                $volumes = Get-BitlockerVolume
                $tpm = Get-Tpm
                switch ($item) {
                    "Volumes" {
                        if ($Json) {
                            Write-Output $volumes | ConvertTo-Json -Depth 100
                        }
                        else {
                            Write-Output $volumes | Format-List
                        }
                    }
                    "Keys" {
                        foreach ($vol in $volumes) {
                            $keys = $vol | Get-BitlockerVolume | Select-Object -ExpandProperty KeyProtector
                            foreach ($key in $keys) {
                                if ($key.KeyProtectorType -eq "RecoveryPassword") {
                                    Write-Output $key.RecoveryPassword
                                }
                            }
                        }
                    }
                    "Tpm" {
                        if ($Json) {
                            Write-Output $tpm | ConvertTo-Json -Depth 100
                        }
                        else {
                            Write-Output $tpm
                        }
                    }
                    "TpmHealth" {
                        if (-Not($tpm.TpmPresent -or $tpm.TpmReady -or $tpm.TpmEnabled -or
                                $tpm.TpmActivated)) {
                            Write-Error "Tpm State: Unhealthy"
                        }
                        else {
                            Write-Output "Tpm State: Healthy"
                        }
                    }
                    "Status" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                $status = @{
                                    Volume     = [string]$vol.VolumeStatus
                                    Percentage = $vol.EncryptionPercentage
                                    Status     = [string]$vol.ProtectionStatus 
                                }
                                if ($Json) {
                                    $status | ConvertTo-Json
                                }
                                else {
                                    Write-Output "Status: $($status.Status), Volume: $($status.Volume), Percentage: $($status.Percentage)"
                                }
                            }
                        }
                    }
                }
            }

            #Operation Section - Taking action
            #Only OS encryption
            foreach ($item in $Operation) {
                $volumes = Get-BitlockerVolume
                $tpm = Get-Tpm
                switch ($item) {
                    "Encrypt" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                if ($vol.VolumeStatus -eq "FullyDecrypted") {
                                    if (($tpm.TpmPresent -or $tpm.TpmReady -or $tpm.TpmEnabled -or $tpm.TpmActivated)) {
                                        Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" -Name "UseAdvancedStartup" -ErrorAction SilentlyContinue
                                        Write-Output "Generating recovery password"
                                        $vol | Add-BitLockerKeyProtector -RecoveryPasswordProtector -InformationAction SilentlyContinue | Out-Null
                                        Write-Output "Encrypting volume"
                                        $vol | Enable-Bitlocker -TpmProtector -UsedSpaceOnly -SkipHardwareTest
                                    }
                                    else {
                                        Write-Error "Tpm not in healthy state"
                                    }
                                }
                                else {
                                    Write-Output "Volume already encrypted or in process"
                                }
                            }
                        }
                    }
                    "Decrypt" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                if ($vol.VolumeStatus -eq "FullyEncrypted") {
                                    Write-Output "Clearing automatic unlocking keys"
                                    Clear-BitLockerAutoUnlock | Out-Null
                                    Write-Output "Decrypting Bitlocker volumes"
                                    $vol | Disable-BitLocker | Out-Null
                                }
                                else {
                                    Write-Error "Volume not in FullyEncrypted state"
                                }
                            }
                        }
                    }
                    "Backup" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                $key = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }
                                if ($key) {
                                    Write-Output "Attempting key protector backup for AD and AAD"
                                    $vol | Backup-BitLockerKeyProtector -KeyProtectorId $key.KeyProtectorId -ErrorAction SilentlyContinue | Out-Null
                                    $vol | BackupToAAD-BitLockerKeyProtector -KeyProtectorId $key.KeyProtectorId -ErrorAction SilentlyContinue | Out-Null
                                }
                                else {
                                    Write-Error "No key protector found for backup"
                                }
                            }
                        }
                    }
                    "HealBitlocker" {
                        Set-Service vss -StartupType Manual
                        Set-Service smphost -StartupType Manual
                        Stop-Service SMPHost
                        Stop-Service vss
                        $mof = mofcomp.exe win32_encryptablevolume.mof
                        if ($mof -like "*not found*") {
                            # Set the Windows Management Instrumentation (WMI) service to start automatically
                            Set-Service winmgmt -StartupType Automatic

                            # Add registry keys and values
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name EnableDCOM -Value "Y" -Type String -Force
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name LegacyAuthenticationLevel -Value 2 -Type DWord -Force
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name LegacyImpersonationLevel -Value 3 -Type DWord -Force

                            # Delete registry keys
                            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name DefaultLaunchPermission -Force -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name MachineAccessRestriction -Force -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name MachineLaunchRestriction -Force -ErrorAction SilentlyContinue

                            # Stop services
                            Stop-Service -Name SharedAccess -Force -ErrorAction SilentlyContinue
                            Stop-Service -Name winmgmt -Force -ErrorAction SilentlyContinue

                            # Clear the Wbem Repository
                            Remove-Item "$env:WINDIR\System32\Wbem\Repository\*.*" -Force -Recurse

                            # Register DLLs
                            $system32Path = Join-Path -Path $env:WINDIR -ChildPath "system32\wbem"
                            Set-Location $system32Path
                            regsvr32 /s scecli.dll
                            regsvr32 /s userenv.dll

                            # Compile MOF files
                            mofcomp cimwin32.mof
                            mofcomp cimwin32.mfl
                            mofcomp rsop.mof
                            mofcomp rsop.mfl

                            # Register all DLLs and compile all MOF and MFL files in the current directory and its subdirectories
                            Get-ChildItem -Path $system32Path -Recurse -Filter *.dll | ForEach-Object { regsvr32 /s $_.FullName }
                            Get-ChildItem -Path $system32Path -Filter *.mof | ForEach-Object { mofcomp $_.Name }
                            Get-ChildItem -Path $system32Path -Filter *.mfl | ForEach-Object { mofcomp $_.Name }

                            # Additional MOF compilations
                            mofcomp exwmi.mof
                            mofcomp -n:root\cimv2\applications\exchange wbemcons.mof
                            mofcomp -n:root\cimv2\applications\exchange smtpcons.mof
                            mofcomp exmgmt.mof

                            # Upgrade the WMI repository
                            rundll32 wbemupgd, UpgradeRepository

                            # Clear the catroot2 directory and security logs
                            Stop-Service Cryptsvc -Force -ErrorAction SilentlyContinue
                            Remove-Item "$env:WINDIR\System32\catroot2\*.*" -Force -Recurse
                            Remove-Item "C:\WINDOWS\security\logs\*.log" -Force
                            Start-Service Cryptsvc

                            # Reset the performance counter registry settings and rebuild the base performance counters
                            Set-Location "$env:WINDIR\system32"
                            lodctr /R
                            Set-Location "$env:WINDIR\sysWOW64"
                            lodctr /R

                            # Resync WMI performance counters
                            winmgmt.exe /resyncperf

                            # Unregister and reregister the Microsoft Installer
                            msiexec /unregister
                            msiexec /regserver

                            # Register MSI DLL
                            regsvr32 /s msi.dll

                            # Start the necessary services
                            Start-Service winmgmt
                            Start-Service SharedAccess 
                        }
                    }
                    "Suspend" {
                        Write-Output "TODO"
                    }
                    "Resume" {
                        Write-Output "TODO"
                    }
                    "HealTpm" {
                        Write-Output "TODO"
                    }
                }
            }

            #Operation Section - Taking action
            #Only OS encryption
            foreach ($item in $Operation) {
                $volumes = Get-BitlockerVolume
                $tpm = Get-Tpm
                switch ($item) {
                    "Encrypt" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                if ($vol.VolumeStatus -eq "FullyDecrypted") {
                                    if (($tpm.TpmPresent -or $tpm.TpmReady -or $tpm.TpmEnabled -or $tpm.TpmActivated)) {
                                        Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FVE" -Name "UseAdvancedStartup" -ErrorAction SilentlyContinue
                                        Write-Output "Generating recovery password"
                                        $vol | Add-BitLockerKeyProtector -RecoveryPasswordProtector -InformationAction SilentlyContinue | Out-Null
                                        Write-Output "Encrypting volume"
                                        $vol | Enable-Bitlocker -TpmProtector -UsedSpaceOnly -SkipHardwareTest
                                    }
                                    else {
                                        Write-Error "Tpm not in healthy state"
                                    }
                                }
                                else {
                                    Write-Output "Volume already encrypted or in process"
                                }
                            }
                        }
                    }
                    "Decrypt" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                if ($vol.VolumeStatus -eq "FullyEncrypted") {
                                    Write-Output "Clearing automatic unlocking keys"
                                    Clear-BitLockerAutoUnlock | Out-Null
                                    Write-Output "Decrypting Bitlocker volumes"
                                    $vol | Disable-BitLocker | Out-Null
                                }
                                else {
                                    Write-Error "Volume not in FullyEncrypted state"
                                }
                            }
                        }
                    }
                    "Backup" {
                        foreach ($vol in $volumes) {
                            if ($vol.VolumeType -eq "OperatingSystem") {
                                $key = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }
                                if ($key) {
                                    Write-Output "Attempting key protector backup for AD and AAD"
                                    $vol | Backup-BitLockerKeyProtector -KeyProtectorId $key.KeyProtectorId -ErrorAction SilentlyContinue | Out-Null
                                    $vol | BackupToAAD-BitLockerKeyProtector -KeyProtectorId $key.KeyProtectorId -ErrorAction SilentlyContinue | Out-Null
                                }
                                else {
                                    Write-Error "No key protector found for backup"
                                }
                            }
                        }
                    }
                    "HealBitlocker" {
                        Set-Service vss -StartupType Manual
                        Set-Service smphost -StartupType Manual
                        Stop-Service SMPHost
                        Stop-Service vss
                        $mof = mofcomp.exe win32_encryptablevolume.mof
                        if ($mof -like "*not found*") {
                            # Set the Windows Management Instrumentation (WMI) service to start automatically
                            Set-Service winmgmt -StartupType Automatic

                            # Add registry keys and values
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name EnableDCOM -Value "Y" -Type String -Force
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name LegacyAuthenticationLevel -Value 2 -Type DWord -Force
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name LegacyImpersonationLevel -Value 3 -Type DWord -Force

                            # Delete registry keys
                            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name DefaultLaunchPermission -Force -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name MachineAccessRestriction -Force -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole' -Name MachineLaunchRestriction -Force -ErrorAction SilentlyContinue

                            # Stop services
                            Stop-Service -Name SharedAccess -Force -ErrorAction SilentlyContinue
                            Stop-Service -Name winmgmt -Force -ErrorAction SilentlyContinue

                            # Clear the Wbem Repository
                            Remove-Item "$env:WINDIR\System32\Wbem\Repository\*.*" -Force -Recurse

                            # Register DLLs
                            $system32Path = Join-Path -Path $env:WINDIR -ChildPath "system32\wbem"
                            Set-Location $system32Path
                            regsvr32 /s scecli.dll
                            regsvr32 /s userenv.dll

                            # Compile MOF files
                            mofcomp cimwin32.mof
                            mofcomp cimwin32.mfl
                            mofcomp rsop.mof
                            mofcomp rsop.mfl

                            # Register all DLLs and compile all MOF and MFL files in the current directory and its subdirectories
                            Get-ChildItem -Path $system32Path -Recurse -Filter *.dll | ForEach-Object { regsvr32 /s $_.FullName }
                            Get-ChildItem -Path $system32Path -Filter *.mof | ForEach-Object { mofcomp $_.Name }
                            Get-ChildItem -Path $system32Path -Filter *.mfl | ForEach-Object { mofcomp $_.Name }

                            # Additional MOF compilations
                            mofcomp exwmi.mof
                            mofcomp -n:root\cimv2\applications\exchange wbemcons.mof
                            mofcomp -n:root\cimv2\applications\exchange smtpcons.mof
                            mofcomp exmgmt.mof

                            # Upgrade the WMI repository
                            rundll32 wbemupgd, UpgradeRepository

                            # Clear the catroot2 directory and security logs
                            Stop-Service Cryptsvc -Force -ErrorAction SilentlyContinue
                            Remove-Item "$env:WINDIR\System32\catroot2\*.*" -Force -Recurse
                            Remove-Item "C:\WINDOWS\security\logs\*.log" -Force
                            Start-Service Cryptsvc

                            # Reset the performance counter registry settings and rebuild the base performance counters
                            Set-Location "$env:WINDIR\system32"
                            lodctr /R
                            Set-Location "$env:WINDIR\sysWOW64"
                            lodctr /R

                            # Resync WMI performance counters
                            winmgmt.exe /resyncperf

                            # Unregister and reregister the Microsoft Installer
                            msiexec /unregister
                            msiexec /regserver

                            # Register MSI DLL
                            regsvr32 /s msi.dll

                            # Start the necessary services
                            Start-Service winmgmt
                            Start-Service SharedAccess 
                        }
                    }
                    "Suspend" {
                        Write-Output "TODO"
                    }
                    "Resume" {
                        Write-Output "TODO"
                    }
                    "HealTpm" {
                        Write-Output "TODO"
                    }
                }
            }
        }
        Catch {
            Write-Error $_.Exception
        }
    }

    End {
        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-Not(Get-Command 'Win_ManageBitlocker' -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    Json      = $Json
    Info      = $Info
    Operation = $Operation
}

Win_ManageBitlocker @scriptArgs