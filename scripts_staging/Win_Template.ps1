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
    [string]$LogLevel
)

<# ================================================================================ #>
function Set-LogLevel() {
    <#
	.SYNOPSIS
	Set-LogLevel will set the log level.

	.DESCRIPTION
	Set-LogLevel will set the log level by setting the preference variables to 'Continue'.
	Continue is preferred over SilentlyContinue to get the output.

	.NOTES
	The list of preference variables can be found here:
	https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-5.1#erroractionpreference
	#>
    [CmdletBinding()]
    param (
        [string] $LogLevel
    )

    switch ( $LogLevel.ToLower()) {
        'error' {
            Set-Variable -Scope Global -Name ErrorActionPreference -Value 'Continue'
            Set-Variable -Scope Global -Name WarningPreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name InformationPreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name VerbosePreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name DebugPreference -Value 'SilentlyContinue'
        }
        'warning' {
            Set-Variable -Scope Global -Name ErrorActionPreference -Value 'Continue'
            Set-Variable -Scope Global -Name WarningPreference -Value 'Continue'
            Set-Variable -Scope Global -Name InformationPreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name VerbosePreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name DebugPreference -Value 'SilentlyContinue'
        }
        'info' {
            Set-Variable -Scope Global -Name ErrorActionPreference -Value 'Continue'
            Set-Variable -Scope Global -Name WarningPreference -Value 'Continue'
            Set-Variable -Scope Global -Name InformationPreference -Value 'Continue'
            Set-Variable -Scope Global -Name VerbosePreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name DebugPreference -Value 'SilentlyContinue'
        }
        'verbose' {
            Set-Variable -Scope Global -Name ErrorActionPreference -Value 'Continue'
            Set-Variable -Scope Global -Name WarningPreference -Value 'Continue'
            Set-Variable -Scope Global -Name InformationPreference -Value 'Continue'
            Set-Variable -Scope Global -Name VerbosePreference -Value 'Continue'
            Set-Variable -Scope Global -Name DebugPreference -Value 'SilentlyContinue'
        }
        'debug' {
            Set-Variable -Scope Global -Name ErrorActionPreference -Value 'Continue'
            Set-Variable -Scope Global -Name WarningPreference -Value 'Continue'
            Set-Variable -Scope Global -Name InformationPreference -Value 'Continue'
            Set-Variable -Scope Global -Name VerbosePreference -Value 'Continue'
            Set-Variable -Scope Global -Name DebugPreference -Value 'Continue'
        }
        Default {
            # Info
            Set-Variable -Scope Global -Name ErrorActionPreference -Value 'Continue'
            Set-Variable -Scope Global -Name WarningPreference -Value 'Continue'
            Set-Variable -Scope Global -Name InformationPreference -Value 'Continue'
            Set-Variable -Scope Global -Name VerbosePreference -Value 'SilentlyContinue'
            Set-Variable -Scope Global -Name DebugPreference -Value 'SilentlyContinue'
            # Log the warning after changing the log level. Otherwise the output is ignored (SilentlyContinue).
            Write-Warning ('Undefined LogLevel {0}; Using default of Info' -f $LogLevel)
        }
    }
}

function Get-LogLevel() {
    <#
	.SYNOPSIS
	Get-LogLevel will get the log level.

	.DESCRIPTION
	Get-LogLevel will get the log level (preference variables). Some other common preference variables are
	included as well.
	#>
    [CmdletBinding()]
    param ()

    Write-Output ''
    Write-Output 'Here is the list of logging preferences:'
    Write-Output ('ErrorActionPreference: {0}' -f $PSCmdlet.GetVariableValue('ErrorActionPreference'))
    Write-Output ('WarningPreference: {0}' -f $PSCmdlet.GetVariableValue('WarningPreference'))
    Write-Output ('InformationPreference: {0}' -f $PSCmdlet.GetVariableValue('InformationPreference'))
    Write-Output ('VerbosePreference: {0}' -f $PSCmdlet.GetVariableValue('VerbosePreference'))
    Write-Output ('DebugPreference: {0}' -f $PSCmdlet.GetVariableValue('DebugPreference'))

    Write-Output ''
    Write-Output 'Here is a list of some other preferences:'
    Write-Output ('ConfirmPreference: {0}' -f $PSCmdlet.GetVariableValue('ConfirmPreference'))
    Write-Output ('ProgressPreference: {0}' -f $PSCmdlet.GetVariableValue('ProgressPreference'))
    Write-Output ('ErrorView: {0}' -f $PSCmdlet.GetVariableValue('ErrorView'))
}

# Set the log level of the script. "-LogLevel Debug" will output all Write statements.
# Possible values:
#   Error: Write-Error
#   Warning: Write-Warning
#   Info: Write-Infomration
#   Verbose: Write-Verbose
#   Debug: Write-Debug
if ($LogLevel) {
    # Write-Output has to be used because the preference variables have not been set.
    Write-Output 'Getting log levels'
    Get-LogLevel

    Write-Output 'Setting log levels'
    Set-LogLevel $LogLevel

    # Now that the log level (preference variables) have been set, we can use Write-Verbose.
    Write-Verbose 'Getting log levels'
    Get-LogLevel
    Write-Verbose '--------------------------------------------------'
}

<# ================================================================================ #>
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
