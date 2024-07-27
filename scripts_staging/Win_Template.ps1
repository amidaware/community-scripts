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

<# =======================  Advanced Debug Logging=============================== #>
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

    switch -wildcard ( $LogLevel.ToLower()) {
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
        # The preference variable is "information". Accept "information" and other variants of "info"
        'info*' {
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
            Write-Warning ('Set-LogLevel(): Undefined LogLevel {0}; Using default of Info' -f $LogLevel)
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
    Write-Output 'Get-LogLevel(): Here is the list of logging preferences:'
    Write-Output ('Get-LogLevel(): ErrorActionPreference: {0}' -f $PSCmdlet.GetVariableValue('ErrorActionPreference'))
    Write-Output ('Get-LogLevel(): WarningPreference: {0}' -f $PSCmdlet.GetVariableValue('WarningPreference'))
    Write-Output ('Get-LogLevel(): InformationPreference: {0}' -f $PSCmdlet.GetVariableValue('InformationPreference'))
    Write-Output ('Get-LogLevel(): VerbosePreference: {0}' -f $PSCmdlet.GetVariableValue('VerbosePreference'))
    Write-Output ('Get-LogLevel(): DebugPreference: {0}' -f $PSCmdlet.GetVariableValue('DebugPreference'))

    Write-Output ''
    Write-Output 'Get-LogLevel(): Here is a list of some other preferences:'
    Write-Output ('Get-LogLevel(): ConfirmPreference: {0}' -f $PSCmdlet.GetVariableValue('ConfirmPreference'))
    Write-Output ('Get-LogLevel(): ProgressPreference: {0}' -f $PSCmdlet.GetVariableValue('ProgressPreference'))
    Write-Output ('Get-LogLevel(): ErrorView: {0}' -f $PSCmdlet.GetVariableValue('ErrorView'))
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


<# ========================  Simple Debug Logging  ================================ #>

param (
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

<# ================================================================================ #>
function Test-TlsVersion([string]$MinTlsVersion = "Tls12") {
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
Test-TlsVersion "Tls"


<# ================================================================================ #>
function Test-PowerShellVersion([string]$MinPsVersion = '2.0') {
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
        Write-Output ('Test-PowerShellVersion(): PowerShell version "{0}" supported' -f $PsVersionTable.PSVersion)
        Write-Verbose ('Test-PowerShellVersion(): Requested minimum version "{0}"' -f $MinPsVersion)
        return $True
    }
    else {
        Write-Warning ('Test-PowerShellVersion(): PowerShell version "{0}" is not supported' -f $PsVersionTable.PSVersion)
        Write-Verbose ('Test-PowerShellVersion(): Requested minimum version "{0}"' -f $MinPsVersion)
        return $False
    }
}
if (Test-PowerShellVersion '8.0') {
    Write-Verbose ('Test-PowerShellVersion(): PowerShell version "{0}" supported' -f "8.0")
}


<# ================================================================================ #>
function Test-IsAdmin() {
    # Test-Admin will return true if the script is running as an administrator.
    # Mandatory Label\High Mandatory Level is when the script is run from an elevated session.
    # Mandatory Label\System Mandatory Level is when the script is run from SYSTEM.
    $Whoami = & "C:/Windows/System32/whoami.exe" /groups
    if (($Whoami -match "Mandatory Label\\High Mandatory Level") -or
            ($Whoami -match "Mandatory Label\\System Mandatory Level")) {
        return $true
    }
    return $false

}
if (Test-IsAdmin) {
    Write-Verbose ('Test-IsAdmin(): Script is running as an administrator')
}


<# ================================================================================ #>
function Test-IsInteractiveShell {
    # https://stackoverflow.com/questions/9738535/powershell-test-for-noninteractive-mode
    # Test each Arg for match of abbreviated '-NonInteractive' command.
    $NonInteractive = [Environment]::GetCommandLineArgs() | Where-Object { $_ -like '-NonI*' }

    if ([Environment]::UserInteractive -and -not$NonInteractive) {
        # We are in an interactive shell.
        return $true
    }
    return $false
}
if (Test-IsInteractiveShell) {
    Write-Verbose ('Test-IsInteractiveShell(): Script is running in an interactive shell')
}


<# ================================================================================ #>
function Test-Is64Bit {
    # Test-Is64Bit tests if the system is 64-bit operating system.
    return [bool][Environment]::Is64BitOperatingSystem
}
if (Test-Is64Bit) {
    Write-Verbose ('Test-Bit(): Script is running in a 64-bit operating system')
}


<# ================================================================================ #>
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
If ("RunAsUser" -Match "true") {
    # Put this inside an always false conditional so that the template can run without changing the environment.
    InstallRunAsUserRequirements
    Invoke-AsCurrentUser -scriptblock {
        # RunAsUser
    }
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
If ("SetRegistryValue" -Match "true") {
    # Put this inside an always false conditional so that the template can run without changing the environment.
    # $RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    # Set-RegistryValue -registryPath $RegistryPath -name "PersonalizationReportingEnabled" -value 0
    #Set-RegistryValue
}

<# ================================================================================ #>
Function Foldercreate {
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$Paths
    )
    
    foreach ($Path in $Paths) {
        if (!(Test-Path $Path)) {
            New-Item -ItemType Directory -Force -Path $Path
        }
    }
}
Foldercreate -Paths "$env:ProgramData\TacticalRMM\temp", "C:\Temp"