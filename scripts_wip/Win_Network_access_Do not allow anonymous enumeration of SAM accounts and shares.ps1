Write-Output "Network access: Do not allow anonymous enumeration of SAM accounts and shares ..."

$registryPath = "HKLM:\System\CurrentControlSet\Control\Lsa"

$Name = "RestrictAnonymousSAM"
$value = "00000001"
$Type = "DWORD"

IF(!(Test-Path $registryPath))
  {
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}
 ELSE {
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

$Name = "RestrictAnonymous"

IF(!(Test-Path $registryPath))
  {
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}
 ELSE {
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}



 Write-Output "Fixed... bye"