<#
.Synopsis
   Installs Duo Authentication for Windows Logon and RDP
.DESCRIPTION
   Downloads the Duo Auth Logon install for Duo.
   Add additional parameters as needed.
.EXAMPLE
    Win_DuoAuthLogon_Manage -IntegrationKey "ikey" -SecretKey "skey" -ApiHost "apihost-hostname"
.EXAMPLE
    Win_DuoAuthLogon_Manage -IntegrationKey "ikey" -SecretKey "skey" -ApiHost "apihost-hostname" -Uninstall
.EXAMPLE
    Win_DuoAuthLogon_Manage -IntegrationKey "ikey" -SecretKey "skey" -ApiHost "apihost-hostname" -AutoPush 1 -FailOpen 0 -RdpOnly 0
.INSTRUCTIONS
    1. Create a Microsoft RDP application in Duo. Copy the values provided in the details.
    2. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
        a) DuoIntegrationKey as type text
        b) DuoSecretKey as type text
        c) DuoApiHost as type text
        d) DuoLatestVersion as type text
    3. In Tactical RMM, Right-click on each client and select Edit. Fill in the DuoIntegrationKey, DuoSecretKey, and DuoApiHost.
    4. Create the follow script arguments
        a) -IntegrationKey {{client.DuoIntegrationKey}}
        b) -SecretKey {{client.DuoSecretKey}}
        c) -ApiHost {{client.DuoApiHost}}
        d) -LatestVersion {{client.DuoLatestVersion}}
.NOTES
   Version: 1.1
   Author: redanthrax
   Creation Date: 2022-04-12
   Update Date: 2024-03-22
#>

Param(
    [string]$IntegrationKey,

    [string]$SecretKey,

    [string]$ApiHost,

    [string]$LatestVersion = "4.2.2.1755",

    [ValidateSet("1", "0")]
    $AutoPush = "1",

    [ValidateSet("1", "0")]
    $FailOpen = "0",

    [ValidateSet("1", "0")]
    $RdpOnly = "0",

    [ValidateSet("1", "0")]
    $Smartcard = "0",

    [ValidateSet("1", "0")]
    $WrapSmartcard = "0",

    [ValidateSet("1", "0")]
    $EnableOffline = "1",

    [ValidateSet("2", "1", "0")]
    $UsernameFormat = "1",

    [switch]$Uninstall
)

function Compare-SoftwareVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version1,

        [Parameter(Mandatory = $true)]
        [string]$Version2
    )

    # Split the version strings into individual parts
    $versionParts1 = $Version1 -split '\.'
    $versionParts2 = $Version2 -split '\.'

    # Get the minimum number of parts between the two versions
    $minParts = [Math]::Min($versionParts1.Count, $versionParts2.Count)

    # Compare the version parts
    for ($i = 0; $i -lt $minParts; $i++) {
        $part1 = [int]$versionParts1[$i]
        $part2 = [int]$versionParts2[$i]

        if ($part1 -gt $part2) {
            return $true
        }
        elseif ($part1 -lt $part2) {
            return $false
        }
    }

    # If all parts are equal, check the length of the version strings
    if ($versionParts1.Count -gt $versionParts2.Count) {
        # Check the additional part in Version1
        $additionalPart = $versionParts1[$minParts..($versionParts1.Count - 1)] -join '.'
        return ![string]::IsNullOrEmpty($additionalPart)
    }
    elseif ($versionParts1.Count -lt $versionParts2.Count) {
        # Check the additional part in Version2
        $additionalPart = $versionParts2[$minParts..($versionParts2.Count - 1)] -join '.'
        return [string]::IsNullOrEmpty($additionalPart)
    }

    return $true
}

function ConvertTo-StringData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [HashTable[]]$HashTable
    )
    process {
        $data = ''
        foreach ($item in $HashTable) {
            foreach ($entry in $item.GetEnumerator()) {
                $data += "{0}=`"{1}`" " -f $entry.Key, $entry.Value
            }
        }

        return $data.Trim()
    }
}

function Win_DuoAuthLogon_Manage {
    [CmdletBinding(DefaultParameterSetName = 'InstallSet')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'InstallSet')]
        [string]$IntegrationKey,

        [Parameter(Mandatory = $true, ParameterSetName = 'InstallSet')]
        [string]$SecretKey,

        [Parameter(Mandatory = $true, ParameterSetName = 'InstallSet')]
        [string]$ApiHost,

        [string]$LatestVersion,

        [ValidateSet("1", "0")]
        $AutoPush = "1",

        [ValidateSet("1", "0")]
        $FailOpen = "0",

        [ValidateSet("1", "0")]
        $RdpOnly = "0",

        [ValidateSet("1", "0")]
        $Smartcard = "0",

        [ValidateSet("1", "0")]
        $WrapSmartcard = "0",

        [ValidateSet("1", "0")]
        $EnableOffline = "1",

        [ValidateSet("2", "1", "0")]
        $UsernameFormat = "1",

        [Parameter(Mandatory = $true, ParameterSetName = 'UninstallSet')]
        [switch]$Uninstall
    )

    Begin {
        $Upgrade = $false
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        if ($null -ne ($Apps | Where-Object { $_.DisplayName -Match "Duo Authentication" }) -and -Not($Uninstall)) {
            $duo = $Apps | Where-Object { $_.DisplayName -Match "Duo Authentication" }
            if ($duo.GetType().Name -eq "Object[]") {
                $duo = $duo[0]
            }

            if (Compare-SoftwareVersion $duo.DisplayVersion $LatestVersion) {
                Write-Output "Duo Authentication $($duo.DisplayVersion) already installed."
                Exit 0
            }
            else {
                $Upgrade = $true
            }
        }

        if ($Uninstall -and $null -eq ($Apps | Where-Object { $_.DisplayName -Match "Duo Authentication" })) {
            Write-Output "Duo Authentication already uninstalled"
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | Sort-Object { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            if ($Uninstall) {
                Write-Output "Uninstalling Duo Authentication for Windows"
                $uninstallString = ($Apps | Where-Object { $_.DisplayName -Match "Duo Authentication" }).UninstallString
                if ($uninstallString) {
                    if ($uninstallString.GetType().Name -eq "Object[]") {
                        foreach ($unst in $uninstallString) {
                            $m = [regex]::Match($unst, '')
                            if ($unst -like "*`"*") {
                                $m = [regex]::Match($unst, '^"([^"]+)"\s*(.*)')
                            }
                            else {
                                $m = [regex]::Match($unst, '^(.*?)\s(.*)$')
                            }

                            $path = $m.Groups[1].Value
                            $arguments = $m.Groups[2].Value
                            if ($path.ToLower() -like "*msiexec*") {
                                Start-Process $path -ArgumentList $arguments, "/quiet", "/qn", "/noreboot" -Wait -NoNewWindow
                            }
                            else {
                                Start-Process $path -ArgumentList $arguments, "/x", "/s", "/v/qn" -Wait -NoNewWindow
                            }
                        }
                    }
                    else {
                        $m = [regex]::Match($uninstallString, '^"([^"]+)"\s*(.*)')
                        $path = $m.Groups[1].Value
                        $arguments = $m.Groups[2].Value
                        if ($path.ToLower() -like "*msiexec*") {
                            Start-Process $path -ArgumentList $arguments, "/quiet", "/qn", "/noreboot" -Wait -NoNewWindow
                        }
                        else {
                            Start-Process $path -ArgumentList $arguments, "/x", "/s", "/v/qn" -Wait -NoNewWindow
                        }
                    }

                    Write-Output "Uninstalled Duo Authentication for Windows"
                }
                else {
                    Write-Output "App uninstall via exe."
                    $destination = "C:\packages$random\duo-win-login-latest.exe"
                    Invoke-WebRequest -Uri "https://dl.duosecurity.com/duo-win-login-latest.exe" -OutFile $destination
                    $myargs = "/x", "/s", "/v/qn"
                    Start-Process "$destination" -ArgumentList $myargs
                    Start-Sleep -Seconds 5
                    Write-Output "Uninstalled Duo Authentication for Windows"
                }

                Write-Output "Validating Duo uninstall complete"

                $Apps = @()
                $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                if ($null -ne ($Apps | Where-Object { $_.DisplayName -Match "Duo Authentication" })) {
                    Write-Error "Duo detected, uninstall failed"
                }
                else {
                    Write-Output "Duo not detected, uninstall complete"
                }

                return
            }

            if ($Upgrade) {
                Write-Output "Attempting upgrade of Duo."
            }

            Write-Output "Starting installation."
            $source = "https://dl.duosecurity.com/duo-win-login-latest.exe"
            $destination = "C:\packages$random\duo-win-login-latest.exe"
            Write-Output "Downloading file."
            Invoke-WebRequest -Uri $source -OutFile $destination
            $options = @{
                IKEY           = $IntegrationKey
                SKEY           = $SecretKey
                HOST           = $ApiHost
                AUTOPUSH       = $AutoPush
                FAILOPEN       = $FailOpen
                RDPONLY        = $RdpOnly
                SMARTCARD      = $Smartcard
                WRAPSMARTCARD  = $WrapSmartcard
                ENABLEOFFLINE  = $EnableOffline
                USERNAMEFORMAT = $UsernameFormat
            }

            $optionsString = ConvertTo-StringData $options
            $arguments = @("/S", "/V`" /qn $optionsString`"")
            Write-Output "Starting install file."
            $process = Start-Process -NoNewWindow -FilePath $destination -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | Stop-Process
                Write-Output "Install timed out after 300 seconds."
                Exit 1
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code."
                Exit 1
            }

            if ($Upgrade) {
                Write-Output "Duo upgraded."
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        if ($error) {
            Exit 1
        }

        Write-Output "Management complete."
        Exit 0
    }
}

if (-not(Get-Command 'Win_DuoAuthLogon_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{}

if ($IntegrationKey) {
    $scriptArgs = @{
        IntegrationKey = $IntegrationKey
        SecretKey      = $SecretKey
        ApiHost        = $ApiHost
        LatestVersion  = $LatestVersion
        AutoPush       = $AutoPush
        FailOpen       = $FailOpen
        RdpOnly        = $RdpOnly
        Smartcard      = $Smartcard
        WrapSmartcard  = $WrapSmartcard
        EnableOffline  = $EnableOffline
        UsernameFormat = $UsernameFormat
    }
}
if ($Uninstall) {
    $scriptArgs = @{
        Uninstall = $Uninstall
    }
}
 
Win_DuoAuthLogon_Manage @scriptArgs