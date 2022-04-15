Write-Output "Disabling PreviewBuilds Experimental Ackknowledge ..."

$registryPath = "HKLM:\Software\Policies\Microsoft\Windows\PreviewBuilds\EnableConfigFlighting"

$Name = "AllowTelemetry"

$value = "00000000"

$Type = "DWORD"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

Write-Output "Done... bye"