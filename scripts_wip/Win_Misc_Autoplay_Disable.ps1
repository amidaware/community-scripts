# Need to parameterize with enable and disable

Write-Output "Disabling Autoplay ..."

$registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"

$Name = "NoDriveTypeAutoRun"

$value = "255"

$Type = "DWORD"

IF (!(Test-Path $registryPath))
{

  New-Item -Path $registryPath -Force | Out-Null

  New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null
}

ELSE {

  New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null
}

Write-Output "Done... bye"