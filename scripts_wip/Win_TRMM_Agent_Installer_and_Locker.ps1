<#
.SYNOPSIS
    Script to install and configure the Tactical RMM (TRMM) Agent.

.DESCRIPTION
    This script performs several tasks to install and secure the Tactical RMM (TRMM) Agent on a Windows machine.
    It includes setting up necessary prerequisites, installing the TRMM agent, configuring Windows Defender exclusions, 
    locking down services, and preventing access to specific folders.

.PARAMETER RMMurl
    The deployment URL to download the Tactical RMM Agent installer.

.EXAMPLE
    $RMMurl = "https://example.com/path/to/agent.exe"
    # (Run the script with the specified URL)
    # This will download and install the TRMM agent, configure exclusions, lock services, and secure folders.

.NOTES
    v1.0 8/22/2024 CBG_ITSUP Initial version
#>

###############################################
######           Prerequisites              ####
###############################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$RMMurl = "Insert RMM agent URL here"

$Path = Test-Path -Path "C:\Program Files\TacticalAgent\tacticalrmm.exe"

###############################################
############   Install TRMM Agent      ########
###############################################

If ($Path -eq $false) {

    Add-MpPreference -ExclusionPath "C:\ProgramData"

    Invoke-WebRequest $RMMurl -OutFile "C:\ProgramData\trmm-agent.exe"

    Start-Process -Wait "C:\ProgramData\trmm-agent.exe" -ArgumentList '-silent'

    Remove-MpPreference -ExclusionPath "C:\ProgramData"

    Remove-Item "C:\ProgramData\trmm-agent.exe" -Force

}
###############################################
### Exclude TRMM paths in Windows Defender ####
###############################################

Add-MpPreference -ExclusionPath "C:\Program Files\Mesh Agent\*"
Add-MpPreference -ExclusionPath "C:\Program Files\TacticalAgent\*"
Add-MpPreference -ExclusionPath "C:\ProgramData\TacticalRMM\*"

###############################################
####          Lock Down Services           ####
###############################################

Start-Process -FilePath "$env:comspec" -ArgumentList "/c sc config tacticalrmm start=auto"

Start-Process -FilePath "$env:comspec" -ArgumentList "/c sc start tacticalrmm"

Start-Process -FilePath "$env:comspec" -ArgumentList "/c  sc.exe sdset tacticalrmm D:AR(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;IU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"

Start-Process -FilePath "$env:comspec" -ArgumentList '/c sc config "Mesh Agent" start=auto'

Start-Process -FilePath "$env:comspec" -ArgumentList '/c sc start "Mesh Agent"'

Start-Process -FilePath "$env:comspec" -ArgumentList '/c sc.exe sdset "Mesh Agent" D:AR(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;IU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)'

###############################################
#####   Prevent access to TRMM folders      ###
###############################################

Invoke-Expression -Command:"icacls ""C:\Program Files\TacticalAgent"" /T /setowner system"
Invoke-Expression -Command:"icacls ""C:\Program Files\TacticalAgent\unins000.exe"" /inheritance:d /grant System:F /deny Administrators:F"
Invoke-Expression -Command:"icacls ""C:\Program Files\TacticalAgent"" /T /inheritance:d /grant System:F /deny Administrators:F"

Exit 0