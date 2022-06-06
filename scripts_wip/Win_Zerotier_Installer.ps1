<#
  .SYNOPSIS
    Installs ZeroTier and join to network.
  .DESCRIPTION
    Install ZeroTier and join/configure ZeroTier network.  With the API key, it will also authorize and name the computer on the zerotier controller.
  .SETUP
    Create Global Key for API token called zerotier-api-key.
  .EXAMPLE
    ./InstallZeroTier.ps1 -NetworkID [Network ID]
    ./InstallZeroTier.ps1 -NetworkID [Network ID] -Token [API Token] -Headless
  .PARAMETERS
    -NetworkID (Required) : ZeroTier Network ID for the network you are deploying
    -Token : ZeroTier API access token
    -Headless : Installs ZeroTier with no UI components
    -ManageDNS : Allows ZeroTier to manage DNS
    -GlobalRoutes : Allows ZeroTier managed routes to overlap public IP space
    -DefaultRoute : Allows ZeroTier to override system default route (full tunnel)
  .NOTES
    Requires PowerShell 7 or higher (installed if missing) when using the $Token parameter.
    A UAC prompt will appear during install if -Headless is not used.
  .CREDITS
    https://scripts.redletter.tech/software/installers/zerotier-one
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$NetworkID, # ZeroTier Network ID
    [string]$Token, # ZeroTier API Token
    [switch]$Headless, # Run msi in headless mode
    [Alias('AllowDNS')]
    [switch]$ManageDNS, # Allows ZeroTier to manage DNS
    [Alias('AllowGlobal')]
    [switch]$GlobalRoutes, # Allows ZeroTier managed routes to overlap public IP space
    [Alias('AllowDefault')]
    [switch]$DefaultRoute   # Allows ZeroTier to override system default route (full tunnel)
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

    # Get Node ID
    $NodeID = (cmd /c $ZTCLI info).split(' ')[2]
 
    # API Member object properties
    $Member = @{
        name        = $env:COMPUTERNAME
        description = ''
        config      = @{ authorized = $True }
    } | ConvertTo-Json

    # Prepare API request
    $Params = @{
        Method            = 'Post'
        Uri               = "https://my.zerotier.com/api/network/$NetworkID/member/$NodeID"
        Body              = $Member
        Authentication    = 'Bearer'
        Token             = ConvertTo-SecureString $Token -AsPlainText -Force
        MaximumRetryCount = 3
        RetryIntervalSec  = 5
    }

    # Join network
    Write-Output "Configuring ZeroTier network $NetworkID as $NodeID..."
    if ($Token) { Invoke-RestMethod @Params } else { cmd /c $ZTCLI join $NetworkID }
    
    # Configure ZeroTier client
    if ($ManageDNS) { $AllowDNS = 1 } else { $AllowDNS = 0 }
    if ($GlobalRoutes) { $AllowGlobal = 1 } else { $AllowGlobal = 0 }
    if ($DefaultRoute) { $AllowDefault = 1 } else { $AllowDefault = 0 }
    cmd /c $ZTCLI set $NetworkID allowDNS=$AllowDNS | Out-Null
    cmd /c $ZTCLI set $NetworkID allowGlobal=$AllowGlobal | Out-Null
    cmd /c $ZTCLI set $NetworkID allowDefault=$AllowDefault | Out-Null
}
catch { throw $Error }
finally { Remove-Item $Installer -Force -ErrorAction Ignore }
