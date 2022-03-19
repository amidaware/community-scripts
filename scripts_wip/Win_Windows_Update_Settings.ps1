#From AzulSkyKnight on discord

Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\" -Name "AUOptions" -Value 4
Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\" -Name "AlwaysAutoRebootAtScheduledTime" -Value 1
Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\" -Name "NoAutoRebootWithLoggedOnUsers" -Value 0
Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\" -Name "ScheduledInstallDay" -Value 0
Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\" -Name "ScheduledInstallTime" -Value 1 