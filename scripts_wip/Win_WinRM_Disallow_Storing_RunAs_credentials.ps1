Write-Output "Disallow WinRM from storing RunAs credentials ..."

$registryPath = "HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service"

$Name = "DisableRunAs"

$value = "1"

$Type = "DWORD"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

Write-Output "Done... bye"