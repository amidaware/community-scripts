<#
.SYNOPSIS
    Lock down services and prevent access to TRMM folders.

.DESCRIPTION
    This script configures and starts the "tacticalrmm" and "Mesh Agent" services, setting security descriptors to enforce security. Additionally, it restricts access to the TacticalAgent directory and its executable to prevent unauthorized access.

.NOTES
    v1.0 8/22/2024 CBG_ITSUP Initial version
#>


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