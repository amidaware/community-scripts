<#
.SYNOPSIS
   Short description
   eg Check IP address

.DESCRIPTION
   Long description
   eg Checks IP address on all local network adapters, and returns results

.PARAMETER xx
   Inputs to this cmdlet (if any)

.PARAMETER yy
   Inputs to this cmdlet (if any)

.OUTPUTS
   Output from this cmdlet (if any)

.EXAMPLE
   Example of how to use this cmdlet

.EXAMPLE
   Another example of how to use this cmdlet

.NOTES
   v1.0 1/1/1900 Username
   General Notes for script
#>

param (
    [string]$MinTlsVersion = "Tls1.2",
    [switch]$debug
)

# For setting debug output level. -debug switch will set $debug to true
if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}


function Test-TlsVersion($MinTlsVersion) {
    # Test if TLS 1.2 is supported
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$MinTlsVersion
        Write-Output ("Test-TlsVersion(): TLS version ""{0}"" is supported" -f $MinTlsVersion)
        return $True
    }
    catch {
        Write-Output ("Test-TlsVersion(): TLS version ""{0}"" is not supported" -f $MinTlsVersion)
        return $False
    }
}
Test-TlsVersion

Function InstallRunAsUserRequirements {
    # Install Requirements for RunAsUser
    if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
        Write-Output "Nuget installing"
        Install-PackageProvider -Name NuGet -Force
    }
    else {
        Write-Output "Nuget already installed"
    }
    if (-not (Get-Module -Name RunAsUser -ListAvailable)) {
        Write-Output "RunAsUser installing"
        Install-Module -Name RunAsUser -Force
    }
    else {
        Write-Output "RunAsUser already installed"
    }
}
InstallRunAsUserRequirements

Invoke-AsCurrentUser -scriptblock {
    # RunAsUser
}


function Set-RegistryValue ($registryPath, $name, $value) {
    # For setting registry values
    if (!(Test-Path -Path $registryPath)) {
        # Key does not exist, create it
        New-Item -Path $registryPath -Force | Out-Null
    }
    # Set the value
    Set-ItemProperty -Path $registryPath -Name $name -Value $value
}
# $RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
# Set-RegistryValue -registryPath $RegistryPath -name "PersonalizationReportingEnabled" -value 0
Set-RegistryValue
