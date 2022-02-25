Write-Output "Disabling Windows Feeds and News ..."

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"

$Name = "EnableFeeds"

$value = "00000000"

$Type = "DWORD"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $Type -Force | Out-Null}

Write-Output "Done... bye"