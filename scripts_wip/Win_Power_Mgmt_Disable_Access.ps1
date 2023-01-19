# Hides changing power settings from user. Thx KMH-Admin

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
$keyName = "FlyoutMenuSettings"
$valueName = "ShowSleepOption"
$value = 0

$keyExists = Test-Path "$registryPath\$keyName"

if ($keyExists -eq $false) {
    New-Item -Path $registryPath -Name $keyName | Out-Null
    New-ItemProperty -Path "$registryPath\$keyName" -Name $valueName -Value $value -PropertyType DWORD | Out-Null
}
else {
    Set-ItemProperty -Path "$registryPath\$keyName" -Name $valueName -Value $value
}
