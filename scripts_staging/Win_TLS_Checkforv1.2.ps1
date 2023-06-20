<#
.SYNOPSIS
   Checks if a specific TLS version is supported.

.DESCRIPTION
   This function tests if a given TLS version is supported by the system.

.PARAMETER MinTlsVersion
   Specifies the minimum required TLS version. Default is "Tls1.2".

.NOTES
   Initial release 6/20/2022 NiceGuyIT and silversword411
#>

param (
    [string]$MinTlsVersion = "Tls1.2",
    [string]$MinPsVersion = "5.0"
)

function Test-TlsVersion($MinTlsVersion) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$MinTlsVersion
        Write-Host ("Test-TlsVersion(): TLS version ""{0}"" is supported" -f $MinTlsVersion)
        return $True
    }
    catch {
        Write-Host ("Test-TlsVersion(): TLS version ""{0}"" is not supported" -f $MinTlsVersion)
        return $False
    }
}

function Require-TlsVersion($MinTlsVersion) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$MinTlsVersion
        Write-Host ("Debug: Minimum TLS version ""{0}"" is required" -f $MinTlsVersion)
        Write-Host ("Debug: System TLS version is ""{0}""" -f ([Net.ServicePointManager]::SecurityProtocol))
        return $False
    }
    catch {
        Write-Host ("Error: Minimum TLS version ""{0}"" is required" -f $MinTlsVersion)
        Write-Host ("Error: System TLS version is ""{0}""" -f ([Net.ServicePointManager]::SecurityProtocol))
        $host.SetShouldExit(1)
        Exit
    }
}

function Test-PowerShellVersion($MinPsVersion) {
    <#
    This function tests for the PowerShell version. This is the $PsVersionTable from Windows 7.
    Name                           Value
    ----                           -----
    CLRVersion                     2.0.50727.8806
    BuildVersion                   6.1.7601.17514
    PSVersion                      2.0
    WSManStackVersion              2.0
    PSCompatibleVersions           {1.0, 2.0}
    SerializationVersion           1.1.0.1
    PSRemotingProtocolVersion      2.1
    #>
    if ($PsVersionTable.PSVersion -ge $MinPsVersion) {
        Write-Output ("Test-PowerShellVersion(): PowerShell version ""{0}"" supported" -f $PsVersionTable.PSVersion)
        return $True
    }
    else {
        Write-Output ("Test-PowerShellVersion(): PowerShell version ""{0}"" is not supported" -f $PsVersionTable.PSVersion)
        return $False
    }
}

if (!(Test-PowerShellVersion($MinPsVersion))) {
    Write-Output "Minimum PowerShell version is NOT supported on this system."
    $host.SetShouldExit(1)
    Exit
}
#Write-Output "Test-PowerShellVersion:", (Test-PowerShellVersion($MinPsVersion))
#Write-Output ""
#Write-Output ""

# Get the current value
#Write-Output "Current TLS values:"
#[Net.ServicePointManager]::SecurityProtocol

# List all possible values
#Write-Output "All possible TLS values:"
#[enum]::GetValues('Net.SecurityProtocolType')

Require-TlsVersion($MinTlsVersion)

#Write-Output "Min TLS:", ([Net.ServicePointManager]::SecurityProtocol)
#Write-Output ""
#if (!(Test-TlsVersion($MinTlsVersion) | Write-Host)) {
#    Write-Output "Minimum TLS version is NOT supported on this system."
#    $host.SetShouldExit(1)
#	Exit
#} else {
#    Write-Output "Minimum TLS version is supported on this system."
#}
#Write-Output "Yeah, TLS works!"
