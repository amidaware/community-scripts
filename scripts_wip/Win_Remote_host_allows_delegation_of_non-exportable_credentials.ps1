Write-Output "Remote host allows delegation of non-exportable credentials ..."

$registryPath = "HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation"

$Name = "AllowProtectedCreds"

$value = "00000001"

$Type = "DWORD"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

Write-Output "Done... bye"