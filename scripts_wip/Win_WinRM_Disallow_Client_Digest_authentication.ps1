Write-Output "Disallow WinRM Client Digest authentication ..."

$registryPath = "HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client"

$Name = "AllowDigest"

$value = "0"

$Type = "DWORD"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

Write-Output "Done... bye"