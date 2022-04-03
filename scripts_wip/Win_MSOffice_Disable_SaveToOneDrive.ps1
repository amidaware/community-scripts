if (Get-PackageProvider -Name NuGet) {
    Write-Output "NuGet Already Added"
} 
else {
    Write-Host "Installing NuGet"
    Install-PackageProvider -Name NuGet -Force
} 
 
if (Get-Module -ListAvailable -Name RunAsUser) {
    Write-Output "RunAsUser Already Installed"
} 
else {
    Write-Output "Installing RunAsUser"
    Install-Module -Name RunAsUser -Force
}

If (!(test-path "$env:programdata\Tactical RMM\temp\")) {
    New-Item -ItemType Directory -Force -Path "$env:programdata\Tactical RMM\temp\"
}

If (!(test-path "$env:programdata\Tactical RMM\temp\curpsxpolicy.txt")) {
    $curexpolicy = Get-ExecutionPolicy

    (
        Write-Output $curexpolicy
    )>"$env:programdata\Tactical RMM\temp\curpsxpolicy.txt"
}
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell -Name ExecutionPolicy -Value Unrestricted


REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Office\$Version\Common\General" /f /v PreferCloudSaveLocations /t REG_DWORD /d 0
REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Office\$Version\Common\Internet" /f /v OnlineStorage /t REG_DWORD /d 3

Invoke-AsCurrentUser -scriptblock {
    $Version = $OfficeInstall.GetValue('DisplayVersion')[0..3] -join ""
    New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Office\$Version\Common\General -Name PreferCloudSaveLocations -Value 0  -PropertyType DWORD
    New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Office\$Version\Common\Internet -Name OnlineStorage -Value 3  -PropertyType DWORD
}

$curpsxpol = Get-Content -Path "$env:programdata\Tactical RMM\temp\curpsxpolicy.txt";
    
Set-ExecutionPolicy -ExecutionPolicy $curpsxpol
