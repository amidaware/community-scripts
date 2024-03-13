# 

param(
    [string] $Drive
)

# Set variable for "USB drive" through a search for a unique directory only available on a USB drive.
$Drive = get-psdrive | where {$_.Root -match ":"} |% {if (Test-Path ($_.Root + "VeeamBackup")){$_.Root}}
 
Write-output "Drive is $Drive"

# $param="/createrecoverymediaiso /f:$Drive:\VeeamRecovery$ENV:COMPUTERNAME.iso"
# "C:\Program Files\Veeam\Endpoint Backup\Veeam.EndPoint.Manager.exe" /createrecoverymediaiso /f:$Drive:\VeeamRecovery$ENV:COMPUTERNAME.iso

# Write-output "C:\Program Files\Veeam\Endpoint Backup\Veeam.EndPoint.Manager.exe /createrecoverymediaiso /f:${Drive}:\VeeamRecovery$ENV:COMPUTERNAME.iso"
# Write-output $param

#Get version number
$Path = "C:\Program Files\Veeam\Endpoint Backup\Veeam.Backup.Core.dll" # Path to Veeam.Backup.Core.dll by default it's located in C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Core.dll
$Item = Get-Item -Path $Path
$Item.VersionInfo.ProductVersion
$item.VersionInfo.Comments


$proc = Start-Process "C:\Program Files\Veeam\Endpoint Backup\Veeam.EndPoint.Manager.exe" -ArgumentList "/createrecoverymediaiso /f:${Drive}\VeeamRecovery$ENV:COMPUTERNAME.iso" -PassThru
    Wait-Process -InputObject $proc
    if ($proc.ExitCode -ne 0) {
        Write-Warning "Exited with error code: $($proc.ExitCode)"
        Write-output $proc
    }
    else {
        Write-Output "Successful install with exit code: $($proc.ExitCode)"
        Write-output $proc
    }
