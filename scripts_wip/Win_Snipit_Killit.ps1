param (
    [switch]$Disable
)


# Disable Snipit
$registryPath = "HKCU:\Control Panel\Keyboard"
$Name = "PrintScreenKeyForSnippingEnabled"
$value = "0"
$currentvalue = Get-ItemPropertyValue -Path $registryPath -Name $Name
Write-Output "Current Value: $currentvalue"

if ($Disable) {
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    Write-Output "Changed reg key"
}