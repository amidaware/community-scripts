#public

<#
.SYNOPSIS
    Script to ensure PowerShell 7+ is installed and set up properly.

.DESCRIPTION
    This script checks if PowerShell 7+ is installed. If not, it installs Chocolatey first, then uses Chocolatey to install PowerShell 7.
    It also sets up the correct rendering for PowerShell 7. 

.NOTES
    Author: SAN

#>

# Check for required PowerShell version (7+)
if (!($PSVersionTable.PSVersion.Major -ge 7)) {
  try {
    # Check if Chocolatey is installed
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Output 'Chocolatey is not installed. Installing Chocolatey...'
        # Install Chocolatey
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Output 'Chocolatey installation failed.'
            exit 1
        }
    }
    # Check if PowerShell 7 is installed
    if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Output 'PowerShell 7 is not installed. Installing PowerShell 7...'
        # Install PowerShell 7 using Chocolatey
        choco install powershell-core --install-arguments='"DISABLE_TELEMETRY"'-'"ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1"'-'"ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1"'-'"REGISTER_MANIFEST=1"' -y
        if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Write-Output 'PowerShell 7 installation failed.'
            exit 1
        }
    }
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    # Restart script in PowerShell 7
    pwsh -File "`"$PSCommandPath`"" @PSBoundParameters
  }
  catch {
    Write-Output 'Error occurred while installing PowerShell 7.'
    throw $Error
    exit 1
  }
  finally { exit $LASTEXITCODE }
}

#Set the correct rendering for pwsh
$PSStyle.OutputRendering = "plaintext"