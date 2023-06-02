<#
  .SYNOPSIS
    Update ZeroTier
  .DESCRIPTION
    Updates ZeroTier
  .EXAMPLE
    ./UpdateZeroTier.ps1
    ./UpdateZeroTier.ps1 -Headless
  .PARAMETERS
    -Headless : Installs ZeroTier with no UI components
  .NOTES
    Requires PowerShell 7 or higher (installed if missing) when using the $Token parameter.
    A UAC prompt will appear during install if -Headless is not used.
  .CREDITS
    Original: https://scripts.redletter.tech/software/installers/zerotier-one
    Edited by Jeevis
#>

param (
  [switch]$Headless      # Run msi in headless mode
)

$DownloadURL = 'https://download.zerotier.com/dist/ZeroTier%20One.msi'
$Installer = "$env:temp\ZeroTierOne.msi"
$ZTCLI = 'C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat'

# Set PowerShell to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($Token) {
  # Check for required PowerShell version (7+)
  if (!($PSVersionTable.PSVersion.Major -ge 7)) {
    try {
    
      # Install PowerShell 7 if missing
      if (!(Test-Path "$env:SystemDrive\Program Files\PowerShell\7")) {
        Write-Output 'Installing PowerShell version 7...'
        Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
      }

      # Refresh PATH
      $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    
      # Restart script in PowerShell 7
      pwsh -File "`"$PSCommandPath`"" @PSBoundParameters
    
    }
    catch {
      Write-Output 'PowerShell 7 was not installed. Update PowerShell and try again.'
      throw $Error
    }
    finally { exit $LASTEXITCODE }
  }
}

try {
  Write-Output 'Downloading ZeroTier...'
  Invoke-WebRequest -Uri $DownloadURL -OutFile $Installer
  
  Write-Output 'Installing ZeroTier...'
  if ($Headless) {
    # Install & unhide from installed programs list
    cmd /c msiexec /i $Installer /qn /norestart 'ZTHEADLESS=Yes'
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { $RegKey = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{002609B2-C32C-481A-B17F-B7ED428427AC}' }
    else { $RegKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{002609B2-C32C-481A-B17F-B7ED428427AC}' }
    Remove-ItemProperty -Path $RegKey -Name 'SystemComponent' -ErrorAction Ignore
  }
  else {
    # Install & close ui
    cmd /c msiexec /i $Installer /qn /norestart
    Stop-Process -Name 'zerotier_desktop_ui' -Force -ErrorAction Ignore
  }
}
catch { throw $Error }
finally { Remove-Item $Installer -Force -ErrorAction Ignore }