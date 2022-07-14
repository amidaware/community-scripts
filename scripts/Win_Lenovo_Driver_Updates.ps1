<#
.SYNOPSIS
    Install a third party tool to check for device drivers. It only installs drivers that can be run non-interactively and silent
.REQUIREMENTS
    Lenovo device is needed
.INSTRUCTIONS
    -
.NOTES
	V1.0 Initial Release by https://github.com/maltekiefer
    v1.1 Consistency checking Modules requirements silversword411
#>

if (-not (Get-PackageProvider -Name NuGet)) {
    Install-PackageProvider -Name NuGet -Force
    Write-Output "Installed NuGet"
} 

if (-not (Get-Module -ListAvailable -Name LSUClient)) {
    Install-Module -Name 'LSUClient' -Force
    Write-Output "Installed LSUClient"
}

# Install only packages that can be installed silently and non-interactively

$updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }
$updates | Save-LSUpdate -Verbose
$updates | Install-LSUpdate -Verbose