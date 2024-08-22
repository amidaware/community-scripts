<#
.SYNOPSIS
    Unlock TacticalRMM Agent and optionally remove it.

.DESCRIPTION
    This script unlocks the TacticalRMM Agent by modifying folder permissions and resetting service security descriptors. Additionally, it includes an optional parameter to remove the TacticalRMM Agent if specified.

.PARAMETER remove
    A boolean parameter that, if set to $True, will trigger the removal of the TacticalRMM Agent.

.OUTPUTS
    None

.EXAMPLE
    .\script.ps1 -remove $False
    - Unlocks the TacticalRMM Agent by adjusting permissions and resetting service security descriptors without removing the agent.

.EXAMPLE
    .\script.ps1 -remove $True
    - Unlocks the TacticalRMM Agent and then removes it using its uninstaller.

.NOTES
    v1.0 8/22/2024 CBG_ITSUP Initial version

#>


param (

  [Parameter()]
  [string]$remove
)

#######################################################
############ UnLock TacticalRMM Agent #################
#######################################################

#################### App Folder #######################

Invoke-Expression -Command:"icacls ""C:\Program Files\TacticalAgent"" /T /inheritance:d /grant System:F /grant Administrators:F"

Invoke-Expression -Command:"icacls ""C:\Program Files\TacticalAgent\unins000.exe"" /inheritance:d /grant System:F /grant Administrators:F"

Invoke-Expression -Command:"icacls ""C:\Program Files\TacticalAgent"" /T /inheritance:d /grant System:F /grant Administrators:F"

##################### Services ########################

Start-Process -FilePath "$env:comspec" -ArgumentList "/c sc.exe sdset tacticalrmm D:AR(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;IU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"

Start-Process -FilePath "$env:comspec" -ArgumentList '/c sc.exe sdset "Mesh Agent" D:AR(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;IU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)'


#######################################################
######### Optional: Remove TacticalRMM Agent ##########
#######################################################

If ($remove -eq $True) {
  Start-Process -Wait -FilePath "$env:comspec" -ArgumentList '/c ""C:\Program Files\TacticalAgent\unins000.exe"" /VERYSILENT'
}