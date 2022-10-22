<#
      .SYNOPSIS
      Enables Windows Defender and sets preferences to lock Defender down on workstations Win10+
      .DESCRIPTION
      Windows Defender in its default configuration does basic protections. Running this script will enable many additional settings to increase security.
      .PARAMETER NoControlledFolders
      Adding this parameter will not enable Controlled Folders
      .EXAMPLE
      -NoControlledFolders
      .NOTES
      9/2021 v1 Initial release dinger1986
      11/24/2021 v1.1 adding command parameters for Controller Folder access by Tremor and silversword
      30/03/2022 v1.2 adding command parameter for audit mode for ASR and added extra ASR rules suggested by SDM216
      Not for use on servers
#>

param (
    [switch] $NoControlledFolders,
    [switch] $AuditOnly
)

# Verifies that script is running on Windows 10 or greater
function Check-IsWindows10 {
    if ([System.Environment]::OSVersion.Version.Major -ge "10") {
        Write-Output $true
    }
    else {
        Write-Output $false
    }
}

# Verifies that script is running on Windows 10 1709 or greater
function Check-IsWindows10-1709 {
    if ([System.Environment]::OSVersion.Version.Minor -ge "16299") {
        Write-Output $true
    }
    else {
        Write-Output $false
    }
}

function SetRegistryKey([string]$key, [int]$value) {
    #Editing Windows Defender settings AV via registry is NOT supported. This is a scripting workaround instead of using Group Policy or SCCM for Windows 10 version 1703
    $amRegistryPath = "HKLM:\Software\Policies\Microsoft\Microsoft Antimalware\MpEngine"
    $wdRegistryPath = "HKLM:\Software\Policies\Microsoft\Windows Defender\MpEngine"
    $regPathToUse = $wdRegistryPath #Default to WD path
    if (Test-Path $amRegistryPath) {
        $regPathToUse = $amRegistryPath
    }
    New-ItemProperty -Path $regPathToUse -Name $key -Value $value -PropertyType DWORD -Force | Out-Null
} 

#### Setup Windows Defender Secure Settings

# Start Windows Defender Service
Set-Service -Name "WinDefend" -Status running -StartupType automatic
Set-Service -Name "WdNisSvc" -Status running -StartupType automatic

#  Enable real-time monitoring
Set-MpPreference -DisableRealtimeMonitoring 0

# Enable cloud-deliveredprotection# 
Set-MpPreference -MAPSReporting Advanced

# Enable sample submission# 
Set-MpPreference -SubmitSamplesConsent 1

# Enable checking signatures before scanning# 
Set-MpPreference -CheckForSignaturesBeforeRunningScan 1

# Enable behavior monitoring# 
Set-MpPreference -DisableBehaviorMonitoring 0

# Enable IOAV protection# 
Set-MpPreference -DisableIOAVProtection 0

# Enable script scanning# 
Set-MpPreference -DisableScriptScanning 0

# Enable removable drive scanning# 
Set-MpPreference -DisableRemovableDriveScanning 0

# Enable Block at first sight# 
Set-MpPreference -DisableBlockAtFirstSeen 0

# Enable potentially unwanted apps# 
Set-MpPreference -PUAProtection Enabled

# Schedule signature updates every 8 hours# 
Set-MpPreference -SignatureUpdateInterval 8

# Enable archive scanning# 
Set-MpPreference -DisableArchiveScanning 0

# Enable email scanning# 
Set-MpPreference -DisableEmailScanning 0

if (!(Check-IsWindows10-1709)) {
    # Set cloud block level to 'High'# 
    Set-MpPreference -CloudBlockLevel High

    # Set cloud block timeout to 1 minute# 
    Set-MpPreference -CloudExtendedTimeout 50

    Write-Host # `nUpdating Windows Defender Exploit Guard settings`n#  -ForegroundColor Green 

    if ($NoControlledFolders) {
        # Check if user has run with -NoControlledFolders parameter
        Write-Host "Skipping enabling Controlled folders"
    }
    else {
        Write-Host "Enabling Controlled folders"
        Set-MpPreference -EnableControlledFolderAccess Enabled
    }

    Write-Host # Enabling Network Protection and setting to block mode# 
    Set-MpPreference -EnableNetworkProtection Enabled

    if ($AuditOnly) {
        # Check if user has run with -AuditOnly parameter for ASR Rules
        Write-Host "Enabling Exploit Guard ASR rules and setting to Audit mode"
        #Block abuse of exploited vulnerable signed drivers     
        Set-MpPreference -AttackSurfaceReductionRules_Ids "56a863a9-875e-4185-98a7-b882c64b5ce5" -AttackSurfaceReductionRules_Actions AuditMode
        #Block executable content from email client and webmail
        Add-MpPreference -AttackSurfaceReductionRules_Ids "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" -AttackSurfaceReductionRules_Actions AuditMode
        #Block all Office applications from creating child processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" -AttackSurfaceReductionRules_Actions AuditMode
        #Block Office applications from creating executable content
        Add-MpPreference -AttackSurfaceReductionRules_Ids "3B576869-A4EC-4529-8536-B80A7769E899" -AttackSurfaceReductionRules_Actions AuditMode
        #Block Office applications from injecting code into other processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84" -AttackSurfaceReductionRules_Actions AuditMode
        #Block JavaScript or VBScript from launching downloaded executable content
        Add-MpPreference -AttackSurfaceReductionRules_Ids "D3E037E1-3EB8-44C8-A917-57927947596D" -AttackSurfaceReductionRules_Actions AuditMode
        #Block execution of potentially obfuscated scripts
        Add-MpPreference -AttackSurfaceReductionRules_Ids "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" -AttackSurfaceReductionRules_Actions AuditMode
        #Block Win32 API calls from Office macros
        Add-MpPreference -AttackSurfaceReductionRules_Ids "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B" -AttackSurfaceReductionRules_Actions AuditMode
        #Block executable files from running unless they meet a prevalence, age, or trusted list criterion
        Add-MpPreference -AttackSurfaceReductionRules_Ids "01443614-cd74-433a-b99e-2ecdc07bfc25" -AttackSurfaceReductionRules_Actions AuditMode
        #Use advanced protection against ransomware
        Add-MpPreference -AttackSurfaceReductionRules_Ids "c1db55ab-c21a-4637-bb3f-a12568109d35" -AttackSurfaceReductionRules_Actions AuditMode
        #Block credential stealing from the Windows local security authority subsystem (lsass.exe)
        Add-MpPreference -AttackSurfaceReductionRules_Ids "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" -AttackSurfaceReductionRules_Actions AuditMode
        #Block process creations originating from PSExec and WMI commands
        Add-MpPreference -AttackSurfaceReductionRules_Ids "d1e49aac-8f56-4280-b9ba-993a6d77406c" -AttackSurfaceReductionRules_Actions AuditMode
        #Block untrusted and unsigned processes that run from USB
        Add-MpPreference -AttackSurfaceReductionRules_Ids "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" -AttackSurfaceReductionRules_Actions AuditMode
        #Block Office communication application from creating child processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "26190899-1602-49e8-8b27-eb1d0a1ce869" -AttackSurfaceReductionRules_Actions AuditMode
        #Block Adobe Reader from creating child processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" -AttackSurfaceReductionRules_Actions AuditMode
        #Block persistence through WMI event subscription
        Add-MpPreference -AttackSurfaceReductionRules_Ids "e6db77e5-3df2-4cf1-b95a-636979351e5b" -AttackSurfaceReductionRules_Actions AuditMode
        
    }
    else {
        Write-Host "Enabling Exploit Guard ASR rules and setting to suggested modes"
        #Block abuse of exploited vulnerable signed drivers     
        Set-MpPreference -AttackSurfaceReductionRules_Ids "56a863a9-875e-4185-98a7-b882c64b5ce5" -AttackSurfaceReductionRules_Actions Enabled
        #Block executable content from email client and webmail
        Add-MpPreference -AttackSurfaceReductionRules_Ids "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" -AttackSurfaceReductionRules_Actions Enabled
        #Block all Office applications from creating child processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" -AttackSurfaceReductionRules_Actions Enabled
        #Block Office applications from creating executable content
        Add-MpPreference -AttackSurfaceReductionRules_Ids "3B576869-A4EC-4529-8536-B80A7769E899" -AttackSurfaceReductionRules_Actions Enabled
        #Block Office applications from injecting code into other processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84" -AttackSurfaceReductionRules_Actions Enabled
        #Block JavaScript or VBScript from launching downloaded executable content
        Add-MpPreference -AttackSurfaceReductionRules_Ids "D3E037E1-3EB8-44C8-A917-57927947596D" -AttackSurfaceReductionRules_Actions Enabled
        #Block execution of potentially obfuscated scripts
        Add-MpPreference -AttackSurfaceReductionRules_Ids "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" -AttackSurfaceReductionRules_Actions Enabled
        #Block Win32 API calls from Office macros
        Add-MpPreference -AttackSurfaceReductionRules_Ids "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B" -AttackSurfaceReductionRules_Actions Enabled
        #Block executable files from running unless they meet a prevalence, age, or trusted list criterion
        Add-MpPreference -AttackSurfaceReductionRules_Ids "01443614-cd74-433a-b99e-2ecdc07bfc25" -AttackSurfaceReductionRules_Actions Enabled
        #Use advanced protection against ransomware
        Add-MpPreference -AttackSurfaceReductionRules_Ids "c1db55ab-c21a-4637-bb3f-a12568109d35" -AttackSurfaceReductionRules_Actions Enabled
        #Block credential stealing from the Windows local security authority subsystem (lsass.exe)
        Add-MpPreference -AttackSurfaceReductionRules_Ids "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" -AttackSurfaceReductionRules_Actions AuditMode
        #Block process creations originating from PSExec and WMI commands
        Add-MpPreference -AttackSurfaceReductionRules_Ids "d1e49aac-8f56-4280-b9ba-993a6d77406c" -AttackSurfaceReductionRules_Actions Enabled
        #Block untrusted and unsigned processes that run from USB
        Add-MpPreference -AttackSurfaceReductionRules_Ids "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" -AttackSurfaceReductionRules_Actions Enabled
        #Block Office communication application from creating child processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "26190899-1602-49e8-8b27-eb1d0a1ce869" -AttackSurfaceReductionRules_Actions AuditMode
        #Block Adobe Reader from creating child processes
        Add-MpPreference -AttackSurfaceReductionRules_Ids "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" -AttackSurfaceReductionRules_Actions AuditMode
        #Block persistence through WMI event subscription
        Add-MpPreference -AttackSurfaceReductionRules_Ids "e6db77e5-3df2-4cf1-b95a-636979351e5b" -AttackSurfaceReductionRules_Actions Enabled
    }

    if ($false -eq (Test-Path ProcessMitigation.xml)) {
        Write-Host # Downloading Process Mitigation file from https://demo.wd.microsoft.com/Content/ProcessMitigation.xml# 
        $url = 'https://demo.wd.microsoft.com/Content/ProcessMitigation.xml'
        Invoke-WebRequest $url -OutFile ProcessMitigation.xml
    }

    Write-Host # Enabling Exploit Protection# 
    Set-ProcessMitigation -PolicyFilePath ProcessMitigation.xml

}

else {
    # #  Workaround for Windows 10 version 1703
    # Set cloud block level to 'High'# 
    SetRegistryKey -key MpCloudBlockLevel -value 2

    # Set cloud block timeout to 1 minute# 
    SetRegistryKey -key MpBafsExtendedTimeout -value 50
}

Write-Host # `nSettings update complete#   -ForegroundColor Green

Write-Host # `nOutput Windows Defender AV settings status#   -ForegroundColor Green
Get-MpPreference
