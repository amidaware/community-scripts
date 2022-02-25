Write-Output "Vulnerability in ATM Font Driver Could Allow Elevation of Privilege (3077657) ..."

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows"

$Name = "DisableATMFD"

$value = "00000001"

$Type = "DWORD"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 Write-Output "Fixed... bye"